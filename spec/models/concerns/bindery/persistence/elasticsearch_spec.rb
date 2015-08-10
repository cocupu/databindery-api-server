require 'rails_helper'

describe Bindery::Persistence::ElasticSearch do
  let(:pool)    { FactoryGirl.create(:pool) }
  let(:model)   { FactoryGirl.create(:model) }
  let(:node)    { FactoryGirl.create(:node, pool: pool, model:model, data:{"foo"=>"bar"}) }
  describe "add_documents_to_index" do
    it "indexes nodes into elasticsearch" do
      expect(Bindery::Persistence::ElasticSearch::Node::NodeIndexer).to receive(:perform_async).with(node.id)
      Bindery::Persistence::ElasticSearch.add_documents_to_index([node.as_index_document])
    end
  end
end

