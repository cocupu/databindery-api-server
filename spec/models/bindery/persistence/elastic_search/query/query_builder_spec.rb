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
      subject.filters.add_must_match( {first_name:"Arya"} )
      subject.filters.add_should_match( {last_name:"Bajracharya"} )
      subject.filters.add_should_match( {last_name:"Gandhi"} )

      subject.set_query('match', {country:"Nepal"} )

      json = subject.as_json
      expect(json['index']).to eq("IndexName")
      expect(json['type']).to eq("AModelName")
      expect(subject.as_json['body']['query']['filtered']['query']).to eq ({"match"=>{"country"=>"Nepal"}})
      expect(subject.as_json['body']['query']['filtered']['filter']).to eq ({'bool'=>{
                                                                               "must"=>[{"match"=>{"first_name"=>"Arya"}}],
                                                                               "should"=>[{"match"=>{"last_name"=>"Bajracharya"}}, {"match"=>{"last_name"=>"Gandhi"}}]
                                                                           }})
    end
    it "preserves anything that was already set in the #body" do
      subject.body = business_opportunity_email_query
      subject.filters.add_must_match( {foo:"bar"} )
      expect(subject.as_json['body']['query']['filtered']['query']).to eq ({ match: { email: "business opportunity" }}.as_json)
      expect(subject.as_json['body']['query']['filtered']['filter']).to eq ({bool:{
                                                                  must: [{match: { foo: "bar" }},{term: { folder: "inbox" }}]
                                                                }}.as_json)
    end
    describe "when there are aggregations set" do
      it "includes them in the json" do
        subject.add_aggregation("brand")
        expect(subject.as_json['body']['aggregations']).to eq(subject.aggregations.as_json['aggregations'])
      end
    end
  end

  describe "index" do
    it "sets the index" do
      subject.index = "MyIndexName"
      expect(subject.as_json['index']).to eq("MyIndexName")
    end
  end
  describe "type" do
    it "sets the type"  do
      subject.type = "AModelName"
      expect(subject.as_json['type']).to eq("AModelName")
    end
  end
  describe "fields" do
    it "specifies which fields to return in search results" do
      subject.fields = ["first_name", "last_name"]
      expect(subject.as_json['body']['fields']).to eq(["first_name", "last_name"])
    end
    it "supports append operator" do
      subject.fields << "date_of_birth"
      expect(subject.as_json['body']['fields']).to eq(["date_of_birth"])
    end
  end
  describe "query" do
    it "returns a QueryString filter by default" do
      expect(subject.query).to be_instance_of(Bindery::Persistence::ElasticSearch::Query::FilterTypes::QueryString)
    end
    it "does not impact the json if empty" do
      expect(subject.as_json['body']).to be_empty
    end
    describe "if no filters are set" do
      it "renders into ['body']['query']" do
        subject.query.query = "red fox"
        expect(subject.as_json['body']['query']).to eq({"query_string"=>{"query"=>"red fox"}}.as_json)
      end
    end
    describe "if any filters are set" do
      it "renders into ['body']['query']['filtered']['query']" do
        subject.filters.add_must_match( {foo:"bar"} )
        subject.query.query = "red fox"
        expect(subject.as_json['body']['query']['filtered']['query']).to eq({"query_string"=>{"query"=>"red fox"}}.as_json)
      end
    end
    it "can be replaced with a different kind of Filter" do
      subject.set_query('match',{})
      expect(subject.query).to be_kind_of(Bindery::Persistence::ElasticSearch::Query::FilterSet)
    end
  end
  describe "filters" do
    it "returns a FilterSet whose contents are rendered into body[:query][:filtered][:filter]" do
      expect(subject.filters).to be_kind_of(Bindery::Persistence::ElasticSearch::Query::FilterSet)
    end
  end
  describe "sorting" do
    it "does not impact the query json if empty" do
      expect(subject.sort).to be_empty
      expect(subject.as_json['sort']).to be_nil
      expect(subject.as_json['body']['sort']).to be_nil
    end
    it "allows you to add sort arguments" do
      subject.sort << { "name" => "desc" }
      expect(subject.as_json['body']['sort']).to eq([{ "name" => "desc" }])
    end
  end

  describe "facets" do
    it "allows you to add any number of term aggregations (facet queries)" do
      subject.add_facet("gender_identity")
      subject.add_facet("date_of_birth")
      expect(subject.aggregations.as_json).to eq(
                  {
                      "aggregations" => {
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