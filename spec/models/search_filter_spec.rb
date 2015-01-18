require 'rails_helper'

describe SearchFilter do
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
  describe "apply_solr_params" do
    it "should render solr params" do
      subject.field = field
      subject.operator = "+"
      subject.values = ["foo"]
      solr_params, user_params = subject.apply_solr_params({}, {})
      solr_params.should == {fq: ["subject_ssi:\"foo\""]}
      subject.values = ["bar","baz"]
      solr_params, user_params = subject.apply_solr_params({}, {})
      solr_params.should == {fq: ["subject_ssi:\"bar\" OR subject_ssi:\"baz\""]}
    end
    it "should vary solr field name based on field type" do
      subject.operator = "+"
      subject.values = ["foo"]
      subject.field = date_field
      solr_params, user_params = subject.apply_solr_params({}, {})
      solr_params.should == {fq: ["important_date_dtsi:\"foo\""]}
      subject.field = integer_field
      solr_params, user_params = subject.apply_solr_params({}, {})
      solr_params.should == {fq: ["a_number_isi:\"foo\""]}
      subject.field = text_area_field
      solr_params, user_params = subject.apply_solr_params({}, {})
      solr_params.should == {fq: ["notes_tsi:\"foo\""]}
      subject.field.multivalue = true
      solr_params, user_params = subject.apply_solr_params({}, {})
      solr_params.should == {fq: ["notes_tesim:\"foo\""]}
    end
  end
  describe "#apply_solr_params_for_filters" do
    before do
      @grant1 = SearchFilter.new(field:text_area_field, operator:"+", values:["birds"])
      @grant2 = SearchFilter.new(field:location_field, operator:"+", values:["Albuquerque"])
      @restrict1 = SearchFilter.new(field:access_level_field, operator:"+", values:["public"], filter_type:"RESTRICT")
    end
    it "should combine GRANT filters with OR" do
      solr_params, user_params = SearchFilter.apply_solr_params_for_filters([@grant1, @grant2], {}, {})
      solr_params[:fq].should == ['notes_tsi:"birds" OR location_ssi:"Albuquerque"']
    end
    it "should put RESTRICT statements in their own :fq" do
      solr_params, user_params = SearchFilter.apply_solr_params_for_filters([@grant1, @grant2, @restrict1], {}, {})
      solr_params[:fq].should == ['+access_level_ssi:"public"','notes_tsi:"birds" OR location_ssi:"Albuquerque"']
    end
  end
end
