require 'rails_helper'

describe Bindery::Persistence::Dat::Repository do
  let(:dat_dir) { 'tmp/foo' }
  let(:sample_repo_dir) { 'tmp/dat/sample' }
  let(:pool) { FactoryGirl.build(:dat_backed_pool) }
  let(:repo) { described_class.new(pool: pool, dir: dat_dir) }
  let(:existing_index_name) { '3149_2015-10-21_17:10:43' }

  describe '#new' do
    subject { described_class.new(pool: pool) }
    before do
      allow(pool).to receive(:ensure_dat_location).and_return('the-dat-location')
    end
    it { is_expected.to be_kind_of ::Dat::Repository }
    it 'sets the pool attribute and defaults to using the pool\'s dat dir' do
      expect(subject.pool).to eq pool
      expect(subject.dir).to eq 'the-dat-location'
    end
    context 'when a dir is provided' do
      subject { described_class.new(pool: pool, dir: dat_dir) }
      it 'uses the provided dir instead of pool dat_dir' do
        expect(subject.pool).to eq pool
        expect(subject.dir).to eq dat_dir
      end
    end
  end

  describe 'index' do
    let(:diff_json) { File.read(fixture_path+'/dat_diff_json.txt') }
    let(:dat_diff_data) { repo.send(:parse_ndj, diff_json) }
    let(:dataset_names) { ['nuts', 'bolts', 'spanners'] }
    let(:elasticsearch_adapter) { double('elasticsearch') }

    before do
      allow(pool).to receive(:__elasticsearch__).and_return(elasticsearch_adapter)
    end

    context 'with no args' do
      it 'exports all of the current data for all of the datasets and bulk_indexes them' do
        expect(repo).to receive(:datasets).and_return(dataset_names)
        dataset_names.each do |dataset_name|
          batch_double = double("#{dataset_name}-batch")
          expect(repo).to receive(:export_in_batches).with(dataset: dataset_name).and_yield(batch_double)
          expect(repo).to receive(:bulk_index).with(batch_double, index_name: pool.to_param, model_name: dataset_name)
        end
        repo.index
      end
    end

    context ':from ... :to' do
      it 'indexes the changes based on a diff between versions identified by :from and :to hashes' do
        expect(repo).to receive(:diff_in_batches).with('versionHashOne', 'versionHashTwo').and_yield(dat_diff_data)
        expect(repo).to receive(:bulk_index).with(dat_diff_data, index_name: pool.to_param)
        repo.index(from: 'versionHashOne', to: 'versionHashTwo')
      end
    end

    context 'specifying index_name' do
      subject { repo.index(index_name: index_name, from: 'versionHashOne', to: 'versionHashTwo') }
      before do
        allow(repo).to receive(:diff_in_batches).with('versionHashOne', 'versionHashTwo').and_yield(dat_diff_data)
      end
      context 'when the index belongs to the pool' do
        let(:index_name) { existing_index_name }
        before do
          expect(pool.__elasticsearch__).to receive(:require_index_to_be_in_pool!).and_return(nil)
        end
        it 'indexes the data into the named index' do
          expect(repo).to receive(:bulk_index).with(dat_diff_data, index_name: existing_index_name)
          subject
        end
      end
      context 'when the index does not belong to the pool' do
        let(:index_name) { 'taekwondo' }
        before do
          expect(pool.__elasticsearch__).to receive(:require_index_to_be_in_pool!).and_raise(ArgumentError, 'the error message')
        end
        it 'raises an error' do
          expect { subject }.to raise_error(ArgumentError, 'the error message')
        end
      end
    end

  end

  describe 'bulk_index' do
    let(:pool) { FactoryGirl.create(:dat_backed_pool) }
    let(:rows) do
      ['{"key":"128","forks":["f247231b35d48d13a2da6c1648579b1fdd5254695e02bc1127f08a375ecd282d","1a6405b75dbe434346c38d3652294f92479b89d87ab5931c3ea868c0b09574d5"],"versions":[null,{"content":"row","type":"put","key":"128","dataset":"proteins","value":{"Record type":"ATOM","serial":"128","name":"OE1","altLoc":"GLU","resNAme":"A","chainID":"8","resSeq":"7.480","iCode":"-4.479","x":"14.728","y":"1.00","z":"0.00","occupancy":"O"},"version":"1a6405b75dbe434346c38d3652294f92479b89d87ab5931c3ea868c0b09574d5","change":4}]}',
       '{"key":"ABMA","forks":["1a6405b75dbe434346c38d3652294f92479b89d87ab5931c3ea868c0b09574d5","cc6d372787ec69e3a16aab6cfa772f7bc51326c4f8d715460e248170657529c4"],"versions":[null,{"content":"row","type":"put","key":"ABMA","dataset":"plants","value":{"Symbol":"ABMA","Synonym Symbol":"ABMAM","Scientific Name with Author":"Abies magnifica A. Murray var. magnifica","Common Name":"","Family":"Pinaceae"},"version":"cc6d372787ec69e3a16aab6cfa772f7bc51326c4f8d715460e248170657529c4","change":5}]}'
      ]
    end
    let(:index_name) { existing_index_name }
    it 'bulk-indexes the rows, finding or generating models as necessary' do
      datrow1 = DatRow.parse(rows[0], pool: pool)
      datrow2 = DatRow.parse(rows[1], pool: pool)
      expect(datrow1).to receive(:as_elasticsearch).and_return('esdoc1')
      expect(datrow2).to receive(:as_elasticsearch).and_return('esdoc2')
      expect(::DatRow).to receive(:parse).with(rows[0], pool: pool).and_return(datrow1)
      expect(::DatRow).to receive(:parse).with(rows[1], pool: pool).and_return(datrow2)
      expected_bulk_actions = [
          {:index=>{:_index=>index_name, :_type=>"protein", :_id=>"128", :data=>'esdoc1'}},
          {:index=>{:_index=>index_name, :_type=>"plant", :_id=>"ABMA", :data=>'esdoc2'}}
      ]
      expect(Bindery::Persistence::ElasticSearch.client).to receive(:bulk).with(body: expected_bulk_actions)
      repo.bulk_index(rows, index_name: index_name, model_name: 'flowers')
      expect(pool.models.count).to eq 2
      expect(datrow1.model).to eq(pool.models.find_by_code('protein'))
      expect(datrow2.model).to eq(pool.models.find_by_code('plant'))
    end
  end

  describe 'find_or_create_model' do
    let(:model_name) { 'mymodel' }
    subject { repo.send(:find_or_create_model, model_name) }
    context 'if a model already exists with that code' do
      let(:existing_model) { pool.models.create(code:model_name, name:'Foobar') }
      before do
        pool.save
        existing_model.save
      end
      it 'returns the existing model' do
        expect(subject).to eq existing_model
      end
    end
    context 'if there is no model with that code' do
      it 'creates one with the code and name populated' do
        expect{ subject }.to change { pool.models.count }.by(1)
        newmodel = pool.models.last
        expect(newmodel.code).to eq model_name
        expect(newmodel.name).to eq 'Mymodel'
      end
    end
    it 'stores models in cached_models in order minimize SQL queries' do
      repo.cached_models = nil
      created_model = repo.send(:find_or_create_model, model_name)
      expect(repo.cached_models['mymodel']).to eq created_model
      expect(Model).to_not receive(:create_with)
      expect(Model).to_not receive(:find_or_create_by)
      found_model = repo.send(:find_or_create_model, model_name)
      expect(found_model).to be created_model
    end
    it 'singularizes model names' do
      created_model = repo.send(:find_or_create_model, 'dreamers')
      expect(created_model.code).to eq('dreamer')
    end
  end

end
