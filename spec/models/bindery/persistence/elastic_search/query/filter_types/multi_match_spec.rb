require 'rails_helper'
describe Bindery::Persistence::ElasticSearch::Query::FilterTypes::MultiMatch do

  let(:klazz) {Bindery::Persistence::ElasticSearch::Query::FilterTypes::MultiMatch}
  # {multi_match:{query:"bazaar", fields:["*"]}}
  describe "new" do
    it "sets the type to 'multi_match'" do
      expect(subject.type).to eq('multi_match')
    end
    it "accepts multi_match attributes" do
      created = klazz.new('multi_match', type:'most_fields', query:"brown fox", fields:[ "subject", "message" ], tie_breaker:0.3)
      expect(created.multi_match_type).to eq('most_fields')
      expect(created.query).to eq("brown fox")
      expect(created.fields).to eq([ "subject", "message" ])
      expect(created.tie_breaker).to eq(0.3)
    end
  end

  describe "as_json" do
    it "returns an empty hash if query and fields are not set" do
      expect(subject.as_json).to eq({})
    end
    it "returns a multi_match query" do
      subject.fields << "*"
      subject.query = "bazaar"
      expect(subject.as_json).to eq({multi_match:{query:"bazaar", fields:["*"]}}.as_json)
    end
    it "includes optional parameters if they have been set" do
      query = klazz.new('multi_match', type:'most_fields', query:"brown fox", fields:[ "subject", "message" ], tie_breaker:0.3)
      expect(query.as_json).to eq({multi_match:{type:'most_fields', query:"brown fox", fields:[ "subject", "message" ], tie_breaker:0.3}}.as_json)
    end
  end
end
