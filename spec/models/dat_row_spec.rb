require 'rails_helper'

describe DatRow do
  let(:pool) { FactoryGirl.build(:dat_backed_pool) }
  let(:model) { FactoryGirl.build(:model, code:'billion_flowers', name:'Billion Flowers') }
  let(:row_json) { {"content"=>"row", "key"=>"ABAB70", "version"=>"a55dbb9800b7f61fa7a0ea32dfb3000b3dbd24ad6ba7cacb0318510edafc217b", "value"=>{"Symbol"=>"ABAB70", "Synonym Symbol"=>"THAB70", "Scientific Name with Author"=>"Thuidium abietinum (Hedw.) Schimp.", "Common Name"=>"", "Family"=>"Thuidiaceae"}}}
  let(:dat_row) { described_class.parse(row_json, pool: pool, model: model) }

  describe 'as_elasticsearch' do
    subject { dat_row.as_elasticsearch }
    it 'works just like a Node object' do
      expect(subject).to eq( {"Symbol"=>"ABAB70", "Synonym Symbol"=>"THAB70", "Scientific Name with Author"=>"Thuidium abietinum (Hedw.) Schimp.", "Common Name"=>"", "Family"=>"Thuidiaceae", "id"=>"ABAB70", "_bindery_title"=>"ABAB70", "_bindery_node_version"=>"a55dbb9800b7f61fa7a0ea32dfb3000b3dbd24ad6ba7cacb0318510edafc217b", "_bindery_model_name"=>"Billion Flowers", "_bindery_pool"=>nil, "_bindery_format"=>"Node", "_bindery_model"=>nil} )
    end
  end
  describe '#parse' do
    subject { dat_row }
    context 'row_format: :diff' do
      let(:row_json) { '{"key":"128","forks":["f247231b35d48d13a2da6c1648579b1fdd5254695e02bc1127f08a375ecd282d","1a6405b75dbe434346c38d3652294f92479b89d87ab5931c3ea868c0b09574d5"],"versions":[null,{"content":"row","type":"put","key":"128","dataset":"proteins","value":{"Record type":"ATOM","serial":"128","name":"OE1","altLoc":"GLU","resNAme":"A","chainID":"8","resSeq":"7.480","iCode":"-4.479","x":"14.728","y":"1.00","z":"0.00","occupancy":"O"},"version":"1a6405b75dbe434346c38d3652294f92479b89d87ab5931c3ea868c0b09574d5","change":4}]}'}
      it 'recognizes the row json as a row from a dat diff and parses it' do
        expect(subject.data).to eq( {"Record type"=>"ATOM", "serial"=>"128", "name"=>"OE1", "altLoc"=>"GLU", "resNAme"=>"A", "chainID"=>"8", "resSeq"=>"7.480", "iCode"=>"-4.479", "x"=>"14.728", "y"=>"1.00", "z"=>"0.00", "occupancy"=>"O"} )
        expect(subject.persistent_id).to eq('128')
        expect(subject.row_json).to eq JSON.parse(row_json)
        expect(subject.pool).to eq pool
        expect(subject.model).to eq model
        expect(subject.row_format).to eq :diff
      end
    end
    context 'row_format: :export' do
      let(:row_json) { {"content"=>"row", "key"=>"ABAB70", "version"=>"a55dbb9800b7f61fa7a0ea32dfb3000b3dbd24ad6ba7cacb0318510edafc217b", "value"=>{"Symbol"=>"ABAB70", "Synonym Symbol"=>"THAB70", "Scientific Name with Author"=>"Thuidium abietinum (Hedw.) Schimp.", "Common Name"=>"", "Family"=>"Thuidiaceae"}}}
      it 'recognizes the row json as a row from a dat export and parses it' do
        expect(subject.data).to eq ( {"Symbol"=>"ABAB70", "Synonym Symbol"=>"THAB70", "Scientific Name with Author"=>"Thuidium abietinum (Hedw.) Schimp.", "Common Name"=>"", "Family"=>"Thuidiaceae"} )
        expect(subject.persistent_id).to eq('ABAB70')
        expect(subject.pool).to eq pool
        expect(subject.model).to eq model
      end
      context 'when row json is a String' do
        let(:row_json) { '{"content":"row","key":"ABAB70","version":"a55dbb9800b7f61fa7a0ea32dfb3000b3dbd24ad6ba7cacb0318510edafc217b","value":{"Symbol":"ABAB70","Synonym Symbol":"THAB70","Scientific Name with Author":"Thuidium abietinum (Hedw.) Schimp.","Common Name":"","Family":"Thuidiaceae"}}'}
        it 'parses the string as json' do
          expect(subject.row_json).to eq JSON.parse(row_json)
          expect(subject.row_format).to eq :export
        end
      end
    end
  end
end