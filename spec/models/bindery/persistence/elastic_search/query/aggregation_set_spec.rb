require 'rails_helper'
describe Bindery::Persistence::ElasticSearch::Query::AggregationSet do

  describe "as_json" do
    it "returns an empty hash if there are no aggregations" do
      expect(subject.as_json).to eq({})
    end
    it "builds the aggregations portion of an elasticsearch request" do
        subject.add_aggregation("brand")
        subject.add_aggregation("min_price", type:"min", parameters: {field:"price"})
        subject.add_aggregation("prices", type:"histogram", parameters: {field:"price", interval:50})
        expect(subject.as_json).to eq(
                                                    {
                                                        "aggs" => {
                                                            "brand" => {
                                                                "terms" => {
                                                                    "field" => "brand"
                                                                }
                                                            },
                                                            "min_price" => {
                                                                "min" => {
                                                                    "field" => "price",
                                                                }},
                                                            "prices" => {
                                                                "histogram" => {
                                                                    "field" => "price",
                                                                    "interval" => 50
                                                                }}
                                                        }}
                                                )
    end
  end
end
