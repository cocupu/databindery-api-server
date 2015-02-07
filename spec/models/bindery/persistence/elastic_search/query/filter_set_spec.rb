require 'rails_helper'
describe Bindery::Persistence::ElasticSearch::Query::FilterSet do

  let(:klazz) { Bindery::Persistence::ElasticSearch::Query::FilterSet }
  subject{  klazz.new('filter') }

  describe 'initializer' do
    it "creates a FilterSet" do
      filter_set = klazz.new(:match)
      expect(filter_set).to be_kind_of(Bindery::Persistence::ElasticSearch::Query::FilterSet)
      expect(filter_set.type).to eq('match')
      expect(filter_set.filters).to eq([])
    end
    it "supports adding subfilters as Hashes" do
      filter_set = klazz.new(:match, {first_name:"Arya"})
      expect(filter_set.type).to eq('match')
      expect(filter_set.filters).to eq([{first_name:"Arya"}])
      expect(filter_set.as_json).to eq({match:{first_name:"Arya"}}.as_json)
    end
    it "supports setting arrays of subfilters" do
      or_filter = klazz.new(:or, [klazz.new('term', {'subject'=>'bar'}),
                                  klazz.new('term', {'subject'=>'baz'})])
      expect(or_filter.as_json).to eq({or:[ {term:{'subject'=>'bar'}},{term:{'subject'=>'baz'}}]}.as_json)
    end
  end

  describe 'build_appropriate' do
    it "creates a FilterSet" do
      built = klazz.build_appropriate('term',{"foofield"=>"mysticism"})
      expect(built.class).to eq(klazz)
      expect(built.filters).to eq([{"foofield"=>"mysticism"}])
    end
    it "tries to initialize the subfilters correctly" do
      built = klazz.build_appropriate('match')
      expect(built.filters).to eq([])
      expect(built.render_filters_as).to be_nil
      ['or','must','must_not','should'].each do |name|
        built = klazz.build_appropriate(name)
        expect(built.render_filters_as).to eq(Array)
      end
    end
    describe "when bool is requested" do
      it "returns a Bool filter" do
        built = klazz.build_appropriate('bool')
        expect(built.class).to eq(Bindery::Persistence::ElasticSearch::Query::FilterTypes::Bool)
      end
    end
    describe "when multi_match is requested" do
      it "returns a MultiMatch filter" do
        built = klazz.build_appropriate('multi_match')
        expect(built.class).to eq(Bindery::Persistence::ElasticSearch::Query::FilterTypes::MultiMatch)
      end
    end
    describe "when query_string is requested" do
      it "returns a QueryString query" do
        built = klazz.build_appropriate('query_string')
        expect(built.class).to eq(Bindery::Persistence::ElasticSearch::Query::FilterTypes::QueryString)
      end
    end
  end

  describe 'add_filter' do
    it "builds appropriate filter and adds it to the filters array" do
      expect(klazz).to receive(:build_appropriate).with(:match, {first_name:"Arya"}).and_return("stub response")
      subject.add_filter(:match, {first_name:"Arya"})
      expect(subject.filters.first).to eq("stub response")
    end
    it "supports dot notation" do
      subject.add_filter(:must).add_filter(:match, {last_name:"Bajracharya"})
      expect(subject.filters[0].type).to eq('must')
      expect(subject.filters[0].filters[0].type).to eq('match')
      expect(subject.filters[0].filters[0].filters).to eq([{last_name:"Bajracharya"}])
    end
    describe "if subfilters was initialized as an Array" do
      it "flags that subfilters should be rendered as an array" do
        filter = klazz.new('filter',[{'match'=>{'month'=>'December'}}])
        expect(filter.render_filters_as).to eq(Array)
        added_filter =  filter.add_filter(:term, {last_name:"Bajracharya"})
        expect(filter.filters).to eq([{'match'=>{'month'=>'December'}},added_filter])
        expect(filter.render_filters_as).to eq(Array)
      end
    end
  end
  describe "as_json" do
    it "renders a json object that includes all of the subfilters" do
      subject.add_filter(:match, {last_name:"Bajracharya"})
      expect(subject.as_json).to eq({filter:{match:{last_name:"Bajracharya"}}}.as_json)
    end
    describe "if render_filters_as is set to Array" do
      it "adds all of the subfilters as objects within an Array" do
        filter = klazz.new('or',[])
        expect(filter.render_filters_as).to eq(Array)
        filter.add_filter(:term, {last_name:"Stewart"})
        filter.add_filter(:term, {last_name:"Bajracharya"})
        expect(filter.as_json).to eq({or:[{term:{last_name:"Stewart"}},{term:{last_name:"Bajracharya"}}]}.as_json)
      end
    end
    describe "when there are no internal filters set" do
      it "returns an empty hash" do
        expect(subject.as_json).to eq({})
      end
    end
  end
end
