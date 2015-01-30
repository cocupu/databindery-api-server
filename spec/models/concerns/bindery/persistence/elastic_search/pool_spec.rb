require  'rails_helper'

describe Bindery::Persistence::ElasticSearch::Pool, elasticsearch:true do

  subject{ FactoryGirl.create(:pool) }
  let(:elasticsearch) { Bindery::Persistence::ElasticSearch.client }

  it "creates a corresponding elasticsearch index" do
    expect(elasticsearch.indices.get(index: "#{subject.to_param}*", expand_wildcards: 'open').count).to eq 1
  end

  # See: http://www.elasticsearch.org/blog/changing-mapping-with-zero-downtime/
  it "uses aliases, allowing for indexes to be rebuilt and swapped transparently" do
    expect( elasticsearch.indices.get_alias(index: "#{subject.to_param}*", name: subject.to_param).count).to eq 1
  end

  describe 'destroy' do
    it "destroys the elasticsearch index and alias" do
      subject.destroy
      expect(elasticsearch.indices.get(index: "#{subject.to_param}*", expand_wildcards: 'open').count).to eq 0
      expect{ elasticsearch.indices.get_alias(name: subject.id).count }.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
    end
  end
end