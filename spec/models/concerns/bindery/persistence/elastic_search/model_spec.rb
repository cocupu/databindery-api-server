require  'rails_helper'

describe Bindery::Persistence::ElasticSearch::Model, elasticsearch:true do

  let(:elasticsearch) { Bindery::Persistence::ElasticSearch.client }
  subject { FactoryGirl.create(:model, fields_attributes:[{name:"First Name"},{name:"First Name"},{name:"Date of Birth"}]) }

  it "creates a corresponding elasticsearch type" do
    subject.save
    expect(elasticsearch.indices.get_mapping(index: subject.pool.id, type: subject.id).values.first["mappings"]).to have_key(subject.id.to_s)
  end

  it "writes all of its fields to elasticsearch as field mappings" do
    subject.save
    expect(subject.mapping_from_elasticsearch).to eq( "properties" => {"date_of_birth"=>{"type"=>"string"}, "first_name"=>{"type"=>"string"}}  )
  end

  describe "fields_from_elasticsearch" do
    it "builds Field records based on the field mappings in elasticsearch"  # This allows you to rely on elasticsearch to do the dynamic type inspection, then register the fields that it created.
  end

  describe "reconcile_and_update_fields" do
    it "creates or updates fields based on the provided array of Fields" # This is for use in applying fields_from_elasticsearch to the current model.
  end

  describe "modifying fields" do
    # See: http://www.elasticsearch.org/blog/changing-mapping-with-zero-downtime/
    #
    it "handles rebuilding index somewhat transparently"
  end

end