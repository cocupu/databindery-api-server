require 'rails_helper'

describe Exhibit do
  let(:pool) { FactoryGirl.create :pool }
  it "Should have many facets" do
    subject.pool = pool
    subject.facets = ["Age", "Weight", "Marital status"]
    subject.save!
    subject.reload
    expect(subject.facets).to eq ["Age", "Weight", "Marital status"]
  end

  it "Should have many index_fields" do
    subject.pool = pool
    subject.index_fields = ["subject", "first_name", "last_name"]
    subject.save!
    subject.reload
    expect(subject.index_fields).to eq ["subject", "first_name", "last_name"]
  end

  it "should accept_nested_attributes for filters" do
    subject.filters_attributes = [{"field_name"=>"subject", "operator"=>"+", "values"=>["4", "1"]}, {"field_name"=>"collection_owner", "operator"=>"-", "values"=>["Hannah Severin"]}]
    subject.filters.length.should == 2
    subject_filter = subject.filters.select {|f| f.field_name == "subject"}.first
    subject_filter.operator.should == "+"
    subject_filter.values.should == ["4", "1"]
    collection_owner_filter = subject.filters.select {|f| f.field_name == "collection_owner"}.first
    collection_owner_filter.operator.should == "-"
    collection_owner_filter.values.should == ["Hannah Severin"]
  end

  describe "filtering: "  do
    it "should apply filters to query builder" do
      subject.filters << SearchFilter.new(:field=>FactoryGirl.create(:model_field), :operator=>"+", :values=>["1","49"])
      subject.filters << SearchFilter.new(:field=>FactoryGirl.create(:access_level_field), :operator=>"+", :values=>["public"])
      subject.filters << SearchFilter.new(:filter_type=>"RESTRICT", :field=>FactoryGirl.create(:model_name_field), :operator=>"-", :values=>["song","person"])
      subject.filters << SearchFilter.new(:filter_type=>"RESTRICT", :field=>FactoryGirl.create(:location_field), :operator=>"-", :values=>["disk1"])
      query_builder = Bindery::Persistence::ElasticSearch::Query::QueryBuilder.new
      query_builder, user_params = subject.apply_query_params_logic(query_builder, {})
      expect(query_builder.as_json['body']['query']['filtered']['filter']).to eq({bool:{should:[{query:{match:{_bindery_model:"1"}}},{query:{match:{_bindery_model:"49"}}},{query:{match:{access_level:"public"}}}],must_not:[{query:{match:{_bindery_model_name:"song"}}},{query:{match:{_bindery_model_name:"person"}}},{query:{match:{location:"disk1"}}}]}}.as_json)
    end
  end

  it "should have a title" do
    subject.title = "Persons of note"
    subject.title.should == "Persons of note"
  end

  it "should not be valid unless it has a  pool" do
    subject.should_not be_valid
    subject.pool = Pool.create
    subject.should be_valid
  end
  
end
