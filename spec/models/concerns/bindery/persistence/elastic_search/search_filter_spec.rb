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
      elasticsearch_params, user_params = subject.apply_elasticsearch_params({}, {})
      elasticsearch_params.should == {fq: ["subject:\"foo\""]}
      subject.values = ["bar","baz"]
      elasticsearch_params, user_params = subject.apply_elasticsearch_params({}, {})
      elasticsearch_params.should == {fq: ["subject:\"bar\" OR subject:\"baz\""]}
    end
    it "should vary elasticsearch field name based on field type" do
      subject.operator = "+"
      subject.values = ["foo"]
      subject.field = date_field
      elasticsearch_params, user_params = subject.apply_elasticsearch_params({}, {})
      elasticsearch_params.should == {fq: ["important_date:\"foo\""]}
      subject.field = integer_field
      elasticsearch_params, user_params = subject.apply_elasticsearch_params({}, {})
      elasticsearch_params.should == {fq: ["a_number:\"foo\""]}
      subject.field = text_area_field
      elasticsearch_params, user_params = subject.apply_elasticsearch_params({}, {})
      elasticsearch_params.should == {fq: ["notes:\"foo\""]}
      subject.field.multivalue = true
      elasticsearch_params, user_params = subject.apply_elasticsearch_params({}, {})
      elasticsearch_params.should == {fq: ["notes:\"foo\""]}
    end
  end
  describe "#apply_elasticsearch_params_for_filters" do
    before do
      @grant1 = SearchFilter.new(field:text_area_field, operator:"+", values:["birds"])
      @grant2 = SearchFilter.new(field:location_field, operator:"+", values:["Albuquerque"])
      @restrict1 = SearchFilter.new(field:access_level_field, operator:"+", values:["public"], filter_type:"RESTRICT")
    end
    it "should combine GRANT filters with OR" do
      elasticsearch_params, user_params = SearchFilter.apply_elasticsearch_params_for_filters([@grant1, @grant2], {}, {})
      elasticsearch_params[:fq].should == ['notes:"birds" OR location:"Albuquerque"']
    end
    it "should put RESTRICT statements in their own :fq" do
      elasticsearch_params, user_params = SearchFilter.apply_elasticsearch_params_for_filters([@grant1, @grant2, @restrict1], {}, {})
      elasticsearch_params[:fq].should == ['+access_level:"public"','notes:"birds" OR location:"Albuquerque"']
    end
  end
end
