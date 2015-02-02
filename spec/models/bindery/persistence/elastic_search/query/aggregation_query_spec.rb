require 'rails_helper'
describe Bindery::Persistence::ElasticSearch::Query::AggregationQuery do

  subject { Bindery::Persistence::ElasticSearch::Query::AggregationQuery.new("a_field_name") }

  describe "initializer" do
    it "sets defaults for type and field name" do
      ag = Bindery::Persistence::ElasticSearch::Query::AggregationQuery.new("last_name")
      expect(ag.name).to eq("last_name")
      expect(ag.type).to eq("terms")
      expect(ag.field).to eq("last_name")
      expect(ag.field).to eq(ag.parameters[:field])
    end
  end

  describe "as_json" do
    it "returns a json-ready hash that can be merged into the aggregations portion of an elasticsearch query" do
      agg1 = Bindery::Persistence::ElasticSearch::Query::AggregationQuery.new("prices", type:"histogram", parameters: {field:"price", interval:"50"})
      expect(agg1.as_json).to eq( {"prices" => {
                                      "histogram" => {
                                          "field" => "price",
                                          "interval" => "50"
                                      }} } )
    end
  end

  describe "aggregations" do
    it "allows for nested aggregations" do
      expect(subject.aggregations).to be_kind_of(Bindery::Persistence::ElasticSearch::Query::AggregationSet)
    end
  end


end
