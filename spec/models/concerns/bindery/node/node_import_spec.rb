require 'rails_helper'
require 'objspace'

describe Node do
  let(:pool) { FactoryGirl.create(:pool) }
  let(:model) { FactoryGirl.create(:model, pool:pool) }

  describe '#import' do
    it "should import all of the records in a source array (into SQL database)" do
      count_before = Node.count
      source_nodes = (1..10).to_a.map { generate_node_of_size(500) }
      Node.import(source_nodes)
      expect(Node.count).to eq(count_before + source_nodes.count)
    end
  end
  describe '#import_nodes' do
    it "should import all of the records in a source array (into the index)" do
      count_before = Node.count
      source_nodes = (1..2).to_a.map { generate_node_of_size(500) }
      allow(Bindery::Persistence::ElasticSearch::Node::NodeIndexer).to receive(:perform_async)
      Node.import_nodes(source_nodes)
      expect(Node.count).to eq(count_before + source_nodes.count)
      source_nodes.each do |node|
        expect(Bindery::Persistence::ElasticSearch::Node::NodeIndexer).to have_received(:perform_async).with(node.latest_version_id)
      end
    end
  end
  describe '#bulk_import_data' do
    let(:record1) { {"subject" => "foo"} }
    let(:records_to_import) { [record1] }
    let(:wrapper_node) do
      wrapper_node = double("Node")
      expect(Node).to receive(:new).and_return(wrapper_node)
      wrapper_node
    end
    it "assigns persistent_ids for all the records" do
      expect(wrapper_node).to receive(:generate_uuid)
      expect(Node).to receive(:import_nodes).with([wrapper_node])
      Node.bulk_import_data(records_to_import, pool, model)
    end
    context "when +key+ is specified" do
      let(:record1) { {"local_identifier" => "foo579a", "subject" => "foo"} }
      context "when an existing node's data has a matching value for the key" do
        before do
          expect(Node).to receive(:query_elasticsearch).and_return([{"id"=>"existing-persistent-id"}])
        end
        it "uses the persistent_id of the existing node" do
          expect(wrapper_node).to_not receive(:generate_uuid)
          expect(wrapper_node).to receive(:persistent_id=).with("existing-persistent-id")
          expect(Node).to receive(:import_nodes).with([wrapper_node])
          Node.bulk_import_data(records_to_import, pool, model, key:'local_identifier')
        end
      end
      context "when no node exists with a matching value for the key" do
        before do
          expect(Node).to receive(:query_elasticsearch).and_return([])
        end
        it "generates a new persistent_id" do
          expect(wrapper_node).to receive(:generate_uuid)
          expect(Node).to receive(:import_nodes).with([wrapper_node])
          Node.bulk_import_data(records_to_import, pool, model, key:'local_identifier')
        end
      end
    end
    it "imports small batches in a single chunk" do
      compact_source_records = (1..200).to_a.map { generate_node_of_size(500).as_index_document }
      expect(Node).to receive(:import).once
      Node.bulk_import_data(compact_source_records, pool, model)
    end
    it "chunks large batches by memory consumption" do
      pending "Inefficiency of Memory size calculations might make this more unwieldy than worthwhile"
      bulky_source_records = [5.24*1000**2, 6*1000**2, 7*1000**2].map{|size| generate_node_of_size(size)}
      expect(Node).to receive(:import).exactly(3).times
      Node.bulk_import_data(bulky_source_records, pool, model)
    end

  end

  def generate_node_of_size(desired_memory_size)
    node = Node.new(pool:pool, model:model)
    node.data = generate_record_of_size(desired_memory_size)
    node.generate_uuid
    node
  end

  def generate_record_of_size(desired_memory_size)
    record = {}
    counter = 0
    until ObjectSpace.memsize_of(record) >= desired_memory_size
      counter +=1
      record[counter] = [rand(36**10).to_s(36)]
    end
    record
  end
end