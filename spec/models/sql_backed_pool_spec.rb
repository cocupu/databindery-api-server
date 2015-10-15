require 'rails_helper'

describe SqlBackedPool do

  let(:pool)  { described_class.new }
  subject     { pool }

  describe "update_index" do
    it "updates the index with all current nodes" do
      allow(subject).to receive(:node_pids).and_return(["pid1","pid2"])
      ["pid1","pid2"].each_with_index do |pid,index|
        fake_version_id = index
        allow(Node).to receive(:latest_version_id).with(pid).and_return(fake_version_id)
        expect(Bindery::Persistence::ElasticSearch::Node::NodeIndexer).to receive(:perform_async).with(fake_version_id)
      end
      pool.update_index
    end
  end

end