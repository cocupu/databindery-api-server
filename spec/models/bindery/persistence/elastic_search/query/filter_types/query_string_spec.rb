require 'rails_helper'
describe Bindery::Persistence::ElasticSearch::Query::FilterTypes::QueryString do

  let(:klazz) {Bindery::Persistence::ElasticSearch::Query::FilterTypes::QueryString}
  # {multi_match:{query:"bazaar", fields:["*"]}}
  describe "new" do
    it "sets the type to 'query_string'" do
      expect(subject.type).to eq('query_string')
    end
  end

  describe "as_json" do

    it "returns an empty hash if query and fields are not set" do
      expect(subject.as_json).to eq({})
    end
    it "returns a query_string query" do
      subject.query = "bazaar"
      expect(subject.as_json).to eq({query_string:{query:"bazaar"}}.as_json)
    end
    it "passes through all filter_parameters that you provide" do
      # [:query,:default_field,:default_operator,:analyzer,:allow_leading_wildcard,:lowercase_expanded_terms,:enable_position_increments,:fuzzy_max_expansions,:fuzziness,:fuzzy_prefix_length]
      subject.parameters
    end
  end
end