require 'rails_helper'

describe Bindery::ReifyHashJob do
  before do
    ## database should be clean
    @starting_node_count = Node.count
    @pool = FactoryGirl.create :pool
    @model = FactoryGirl.create(:model, fields_attributes: [{code: 'location', name: 'Location'}, {code: 'title_en', name: 'Title'}, {code: 'creator', name: 'Creator'}])
  end
  it "should process" do
    row_content = {"title_en"=>'My Title', "location"=>'Paris, France', "creator"=>'Ken Burns'}
    uuid ||= Resque::Plugins::Status::Hash.generate_uuid
    job = Bindery::ReifyHashJob.new(uuid, {"pool"=>@pool.id, "source_node"=>202, "model"=>@model.id, "row_index"=>3, "row_content"=>row_content})
    returned = job.perform
    Node.count.should == @starting_node_count + 1
    created = Node.first
    created.pool.should == @pool
    created.model.should == @model
    created.data.should == row_content
    created.spawned_from_node_id.should == 202
  end
end
