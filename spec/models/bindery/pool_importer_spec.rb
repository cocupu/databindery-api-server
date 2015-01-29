require 'rails_helper'
require 'bindery'

describe Bindery::PoolImporter do

  let(:identity) { FactoryGirl.create(:identity) }
  let(:pool) { FactoryGirl.create(:pool, owner:identity)}
  let(:source_json_dir) { fixture_path+'/exported_data/pullahari_rdi_images' }
  describe "import_from" do
    it "imports pool, models and nodes from json" do
      expect { result = subject.import_from(source_json_dir, identity, force_create_new:true) }.to change{identity.pools.count}.by(1)
      imported_pool = identity.pools.last
      expect(imported_pool.nodes.count).to eq(7)
      expect(imported_pool.models.count).to eq(3)
      file_entity_model = imported_pool.models.where(uri:"http://api.databindery.com/api/v1/pools/17/models/35").first
      historical_person_model = imported_pool.models.where(uri:"http://api.databindery.com/api/v1/pools/17/models/55").first
      lineage_model = imported_pool.models.where(uri:"http://api.databindery.com/api/v1/pools/17/models/52").first
      expect(file_entity_model.nodes.count).to eq(5)
      expect(historical_person_model.nodes.count).to eq(2)
      expect(lineage_model.nodes.count).to eq(0)
    end
    it "optionally allows you to provide the pool to import into"
  end

  describe "import_pool" do
    it "finds or creates a pool matching the given json"
    it "optionally allows you to force creation of a new pool"
  end

  describe "import_models" do
    it "imports all the models, rebuilding all of their fields, sets label_field, and retains association :references values" do
      original_model_count = pool.models.count
      imported_models_by_uri =subject.import_models(source_json_dir+'/models.json',pool)
      expect(pool.models.count).to eq(original_model_count+3)
      historical_person_model = imported_models_by_uri["http://api.databindery.com/api/v1/pools/17/models/55"]
      lineage_model = imported_models_by_uri["http://api.databindery.com/api/v1/pools/17/models/52"]
      expect(historical_person_model.label_field_id).to eq( historical_person_model.fields.where(code:'name_english').first.id )
      lineage_field = historical_person_model.fields.where(code:'lineages').first
      expect(lineage_field.references).to eq(lineage_model.id)
      # If no URI was set before on each Field, sets it to a URI that references the original Field in the source Pool
      expect(lineage_field.uri).to eq("http://api.databindery.com/api/v1/pools/17/fields/1116")
    end
  end
end
