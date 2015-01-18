require 'rails_helper'

describe Bindery::ReifyRowJob do
  before do
    ## database should be clean
    @starting_node_count = Node.count
    @pool = FactoryGirl.create :pool
    @model = FactoryGirl.create(:model, fields_attributes: [{code: 'location', name: 'Location'}, {code: 'title_en', name: 'Title'}, {code: 'creator', name: 'Creator'}])
    @template = MappingTemplate.new(owner: FactoryGirl.create(:identity))
    @template.model_mappings = [{:name=>"Talk", model_id: @model.id, :field_mappings=>[{:field=>"#title_field_id#", :source=>"0"},{:field=>"#location_field_id#", :source=>"1"},{:field=>"#creator_field_id#", :source=>"2"}]}]
    @template.save!
  end
  it "should process" do
    uuid ||= Resque::Plugins::Status::Hash.generate_uuid
    job = Bindery::ReifyRowJob.new(uuid, {"pool"=>@pool.id, "source_node"=>202, "mapping_template"=>@template.id, "row_index"=>3, "row_content"=>['My Title', 'Paris, France', 'Ken Burns'] })
    returned = job.perform
    Node.count.should == @starting_node_count + 1
    # created = Node.all.select {|n| n != @source_node}.first
    created = Node.first
    created.model.should == @model
    created.data.should == {"#title_field_id#"=>"My Title", "#location_field_id#"=>"Paris, France", "#creator_field_id#"=>"Ken Burns"}
    created.spawned_from_node_id.should == 202
  end
end
