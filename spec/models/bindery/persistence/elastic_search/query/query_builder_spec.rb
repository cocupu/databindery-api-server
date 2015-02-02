require 'rails_helper'
require 'jbuilder'
describe Bindery::Persistence::ElasticSearch::Query::QueryBuilder do
  let(:business_opportunity_email_query) do
    {"query" => {
        "filtered"=> {
          "query"=>  { "match"=> { "email"=> "business opportunity" }},
          "filter"=> { "term"=>  { "folder"=> "inbox" }}
        }
    }}
  end
  describe "as_json" do
    it "renders a valid set of arguments for calling #search on the elasticsearch ruby client" do
      subject.index = "IndexName"
      subject.type = "AModelName"
      subject.filters.must_match << {first_name:"Arya"}
      subject.filters.should_match << {last_name:"Bajracharya"}
      subject.filters.should_match << {last_name:"Gandhi"}
      subject.query.must_match << {country:"Nepal"}

      json = subject.as_json
      expect(json['index']).to eq("IndexName")
      expect(json['type']).to eq("AModelName")
      expect(subject.as_json['body']['query']['filtered']['query']).to eq ({"bool"=>{"must"=>[{"match"=>{"country"=>"Nepal"}}]}})
      expect(subject.as_json['body']['query']['filtered']['filter']).to eq ({'bool'=>{
                                                                               "must"=>[{"match"=>{"first_name"=>"Arya"}}],
                                                                               "should"=>[{"match"=>{"last_name"=>"Bajracharya"}}, {"match"=>{"last_name"=>"Gandhi"}}]
                                                                           }})
    end
    it "preserves anything that was already set in the #body" do
      subject.body = business_opportunity_email_query
      subject.filters.must_match << {foo:"bar"}
      expect(subject.as_json['body']['query']['filtered']['query']).to eq ({ match: { email: "business opportunity" }}.as_json)
      expect(subject.as_json['body']['query']['filtered']['filter']).to eq ({bool:{
                                                                  must: [{match: { foo: "bar" }},{term: { folder: "inbox" }}]
                                                                }}.as_json)
    end
    describe "if any filters are set" do
      it "puts the query inside body[:query][:filtered]"
    end
    describe "if no filters are set" do
      it "puts the query inside body[:query]"
    end
    describe "when there are aggregations set" do
      it "includes them in the json" do
        subject.add_aggregation("brand")
        expect(subject.as_json['aggs']).to eq(subject.aggregations.as_json['aggs'])
      end
    end
  end

  describe "index" do
    it "sets the index" do
      subject.index = "MyIndexName"
      expect(subject.as_json).to eq({index:"MyIndexName", body:{}}.as_json)
    end
  end
  describe "type" do
    it "sets the type"  do
      subject.type = "AModelName"
      expect(subject.as_json).to eq({index:nil, type:"AModelName", body:{}}.as_json)
    end
  end
  describe "fields" do
    it "specifies which fields to return in search results" do
      subject.fields = ["first_name", "last_name"]
      expect(subject.as_json).to eq({index:nil, body:{fields:["first_name", "last_name"]}}.as_json)
    end
    it "supports append operator" do
      subject.fields << "date_of_birth"
      expect(subject.as_json).to eq({index:nil, body:{fields:["date_of_birth"]}}.as_json)
    end
  end
  describe "query" do
    it "returns a FilterSet whose contents are rendered into body[:query]" do
      expect(subject.query).to be_kind_of(Bindery::Persistence::ElasticSearch::Query::FilterSet)
      subject.query.should_match << { "email"=> "business opportunity" }
      subject.query.must_match << { "folder"=> "inbox" }
      subject.query.must_not_match << { "spam"=> true }
    end
  end
  describe "filters" do
    it "returns a FilterSet whose contents are rendered into body[:query][:filtered][:filter]" do
      expect(subject.filters).to be_kind_of(Bindery::Persistence::ElasticSearch::Query::FilterSet)
    end
  end

  describe "multi_match" do
    it "returns a MultiMatchQuery whose contents are rendered into body[:query][:multi_match]" do
      expect(subject.multi_match).to be_kind_of(Bindery::Persistence::ElasticSearch::Query::MultiMatchQuery)
    end
  end
  describe "facets" do
    it "allows you to add any number of term aggregations (facet queries)" do
      subject.add_facet("gender_identity")
      subject.add_facet("date_of_birth")
      expect(subject.aggregations.as_json).to eq(
                  {
                      "aggs" => {
                        "gender_identity" => {
                          "terms" => { "field" => "gender_identity" }
                        },
                        "date_of_birth" => {
                              "terms" => { "field" => "date_of_birth" }
                        }
                      }
                  }
                                        )

    end
  end

  it "delegates add_facet and add_aggregation to its aggregations object" do
    expect(subject.aggregations).to receive(:add_facet)
    subject.add_facet("foo")
    expect(subject.aggregations).to receive(:add_aggregation)
    subject.add_aggregation("bar")
  end
  describe "aggregations" do
    it "is an instance of AggregationSet" do
      expect(subject.aggregations).to be_instance_of(Bindery::Persistence::ElasticSearch::Query::AggregationSet)
    end
  end
  describe "body" do
    it "allows you to directly set the contents of the query body" do
      original_body = business_opportunity_email_query
      subject.body = original_body
      expect(subject.as_json).to eq ( {index:nil, body: business_opportunity_email_query}.as_json )
    end
  end
end