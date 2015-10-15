require 'rails_helper'

describe DatBackedPool do
  let(:dat_location) { 'ssh://my/dat/location/path' }
  let(:pool)  { described_class.new(dat_location: dat_location) }
  subject     { pool }

  describe 'dat' do
    subject { pool.dat }
    it { is_expected.to be_instance_of(Bindery::Persistence::Dat::Repository) }
    it 'points to the pool\'s dat_location' do
      expect(subject.dir).to eq(pool.dat_location)
    end
  end

  describe "update_index" do
    it "updates the index with all current nodes"
  end

  describe 'ensure_dat_location' do
    subject { pool.ensure_dat_location }
      it 'returns the dat_location' do
        expect(subject).to eq( 'ssh://my/dat/location/path')
      end
    context 'when dat_location is not set' do
      let(:dat_location) { nil }
      let(:pool)  { described_class.new(id:2) }
      it 'generates the dat location, sets that attribute, and returns the value' do
        allow(pool).to receive(:persisted?).and_return true
        expect(subject).to eq File.expand_path "dat/2"
        expect(pool.dat_location).to eq(subject)
      end
      context 'if pool is not persisted' do
        let(:pool)  { described_class.new() }
        it 'raises an exception' do
          expect { subject }.to raise_error(RuntimeError, 'Cannot determine dat location for a pool that is not persisted.')
        end
      end
    end
  end

end