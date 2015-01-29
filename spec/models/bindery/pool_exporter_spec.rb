require 'rails_helper'
require 'bindery'

describe Bindery::PoolExporter do

  let(:pool) { FactoryGirl.create(:pool) }
  let(:first_name_field) { FactoryGirl.create :first_name_field }
  let(:last_name_field) { FactoryGirl.create :last_name_field }
  let(:title_field) {Field.create(name:'title', multivalue:true)}
  let(:misc_field) {Field.create(name:'title', multivalue:true)}
  let(:association_field) { FactoryGirl.create :association, references:model1.id }

  let(:model1) {
    FactoryGirl.create(:model, pool:pool,
                       fields: [first_name_field,last_name_field,title_field],
                       label_field: last_name_field)
  }
  let(:model2) {
    FactoryGirl.create(:model, pool:pool,
                       fields: [first_name_field,last_name_field,misc_field,association_field],
                       label_field: last_name_field)
  }

  subject { Bindery::PoolExporter.new }

  describe "export"  do
    before do
      [model1,model2].each do |m|
        7.times do
          node = Node.new(pool:pool, model:m)
          m.fields.each do |f|
            if f.instance_of?(OrderedListAssociation)
              node.data[f.to_param] = [model1.nodes.last.persistent_id,model1.nodes.first.persistent_id]
            else
              node.data[f.to_param] = (0...rand(12)).map { (65 + rand(26)).chr }.join
            end
          end
          node.save
        end
      end
    end

    after do
      FileUtils.rm_rf("tmp/#{pool.persistent_id}")
    end

    it "should export pool, models and nodes to json files" do
      export_path = subject.export(Pool.find(pool.id))
      expect(Dir[export_path+"/*"]).to eq(["#{export_path}/models.json","#{export_path}/nodes.json","#{export_path}/pool.json"])
      # Ensure that the exported content can be parsed from JSON
      exported_pool = JSON.parse( File.open( File.join(export_path,'pool.json') ).first )
      exported_nodes = []
      File.open( File.join(export_path,'nodes.json') ).each {|json| exported_nodes << JSON.parse(json)}
      exported_models = []
      File.open( File.join(export_path,'models.json') ).each {|json| exported_models << JSON.parse(json)}

      # Pool
      expect(exported_pool).to eq(subject.convert_pool(pool).as_json)

      # Models
      expect(exported_models.first).to eq(JSON.parse(subject.convert_model(model1).to_json))
      expect(exported_models.last).to eq(JSON.parse(subject.convert_model(model2.reload).to_json))

      # Nodes
      pool.nodes.each do |n|
        expect(exported_nodes).to include(subject.convert_node_data(n).as_json)
      end
      an_exported_node = exported_nodes[6]
      # Ensure that nodes & models are exported in a way that lets them be reconnected later
      expect(exported_models.map {|m| m['uri']}).to include an_exported_node["bindery_model_uri"]
    end
  end


  describe "convert_model" do
    it "injects model uri and removes (redundant) :associations hash" do
      converted_model = subject.convert_model(model2)
      expect(converted_model['uri']).to eq(model2.to_uri)
      expect(converted_model['associations']).to be_nil
    end
    it "processes association fields to use model uris as their :references values" do
      converted_model = subject.convert_model(model2)
      converted_association_field = converted_model['fields'].select {|f| f['name'] == 'an_association'}.first
      expect(converted_association_field['references']).to eq(model1.to_uri)
    end
  end
end