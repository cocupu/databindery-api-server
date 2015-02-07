require 'rails_helper'

describe Bindery::Persistence::ElasticSearch::SearchFilter do

  subject { SearchFilter.new }

  let(:field) { Field.new(code:"subject") }
  let(:location_field) { Field.new(code:"location") }
  let(:access_level_field) { Field.new(code:"access_level") }
  let(:text_area_field) { TextArea.new(code:"notes") }
  let(:date_field) { DateField.new(code:"important_date") }
  let(:integer_field) { IntegerField.new(code:"a_number") }
  it "should persist" do
    exhibit = Exhibit.new
    exhibit.pool = FactoryGirl.create :pool
    exhibit.save
    subject.field = field
    subject.operator = "+"
    subject.values = ["foo","bar"]
    subject.filterable   = exhibit
    subject.save
    reloaded = SearchFilter.find(subject.id)
    reloaded.field.should == field
    reloaded.operator.should == "+"
    reloaded.values.should == ["foo","bar"]
    reloaded.filterable.should == exhibit
    exhibit.reload.filters.should == [reloaded]
  end
  describe "apply_elasticsearch_params" do
    it "should render elasticsearch params" do
      subject.field = field
      subject.operator = "+"
      subject.values = ["foo"]
      query_builder, user_params = subject.apply_elasticsearch_params()
      expect(query_builder.as_json['body']['query']['filtered']['filter']).to eq({bool:{should:[{query:{match:{'subject'=>'foo'}}}]}}.as_json)
      # expect(query_builder.as_json['body']['query']['filtered']['filter']).to eq({bool:{should:[{match:{'subject'=>'foo'}}]}}.as_json)
      subject.values = ["bar","baz"]
      query_builder, user_params = subject.apply_elasticsearch_params()
      expect(query_builder.as_json['body']['query']['filtered']['filter']).to eq({bool:{should:[{query:{match:{'subject'=>'bar'}}},{query:{match:{'subject'=>'baz'}}}]}}.as_json)
      # expect(query_builder.as_json['body']['query']['filtered']['filter']).to eq({bool:{should:[{match:{'subject'=>'bar'}},{match:{'subject'=>'baz'}}]}}.as_json)
    end
  end
  describe "#apply_elasticsearch_params_for_filters" do
    before do
      @grant1 = SearchFilter.new(field:text_area_field, operator:"+", values:["birds"])
      @grant2 = SearchFilter.new(field:location_field, operator:"+", values:["Albuquerque"])
      @restrict1 = SearchFilter.new(field:access_level_field, operator:"+", values:["faculty"], filter_type:"RESTRICT")
      @restrict2 = SearchFilter.new(field:access_level_field, operator:"+", values:["admin","curator"], filter_type:"RESTRICT")
    end
    it "should combine GRANT filters with bool[:should]" do
      query_builder, user_params = SearchFilter.apply_elasticsearch_params_for_filters([@grant1, @grant2])
      expect(query_builder.as_json['body']['query']['filtered']['filter']).to eq({bool:{should:[{"query"=>{"match"=>{"notes"=>"birds"}}}, {"query"=>{"match"=>{"location"=>"Albuquerque"}}}]}}.as_json)
      # expect(query_builder.as_json['body']['query']['filtered']['filter']).to eq({bool:{should:[{"match"=>{"notes"=>"birds"}}, {"match"=>{"location"=>"Albuquerque"}}]}}.as_json)
    end
    it "puts RESTRICT statements with bool[:must]" do
      query_builder, user_params = SearchFilter.apply_elasticsearch_params_for_filters([@grant1, @grant2, @restrict1])
      expect(query_builder.as_json['body']['query']['filtered']['filter']).to eq({bool:{should:[{"query"=>{"match"=>{"notes"=>"birds"}}}, {"query"=>{"match"=>{"location"=>"Albuquerque"}}}], "must"=>[{"query"=>{"match"=>{"access_level"=>"faculty"}}}]}}.as_json)
      # expect(query_builder.as_json['body']['query']['filtered']['filter']).to eq({bool:{should:[{"match"=>{"notes"=>"birds"}}, {"match"=>{"location"=>"Albuquerque"}}], "must"=>[{"match"=>{"access_level"=>"faculty"}}]}}.as_json)
    end
    it "combindes RESTRICT values with :or" do
      query_builder, user_params = SearchFilter.apply_elasticsearch_params_for_filters([@grant1, @grant2, @restrict2])
      expect(query_builder.as_json['body']['query']['filtered']['filter']).to eq({bool:{should:[{"query"=>{"match"=>{"notes"=>"birds"}}}, {"query"=>{"match"=>{"location"=>"Albuquerque"}}}],must:[{or:[{"query"=>{"match"=>{"access_level"=>"admin"}}}, {"query"=>{"match"=>{"access_level"=>"curator"}}}]}]}}.as_json)
      # expect(query_builder.as_json['body']['query']['filtered']['filter']).to eq({bool:{should:[{"match"=>{"notes"=>"birds"}}, {"match"=>{"location"=>"Albuquerque"}}],must:[{or:[{"match"=>{"access_level"=>"admin"}}, {"match"=>{"access_level"=>"curator"}}]}]}}.as_json)
    end
  end
end
