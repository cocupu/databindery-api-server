require 'rails_helper'

describe Audience do
  let(:subject_field) {Field.create(name:"subject")}
  let(:field2) {Field.create(name:"field2")}
  it "has many search filters" do
    subject.filters.should == []
    @sf = FactoryGirl.create(:search_filter)
    subject.filters << @sf
    subject.save
    subject.filters.should == [@sf]
  end
  it "should render query params based on filters" do
    subject.update_attributes filters_attributes:[{field:subject_field, operator:"+", values:["foo","bar"]}, {filter_type:"RESTRICT", field:field2, operator:"-", values:["baz"]}]
    query_builder = Bindery::Persistence::ElasticSearch::Query::QueryBuilder.new
    query_builder, user_params = subject.apply_query_params(query_builder, {})
    expect(query_builder.as_json['body']['query']['filtered']['filter']).to eq({bool:{should:[{query:{match:{subject:"foo"}}},{query:{match:{subject:"bar"}}}],must_not:[{query:{match:{field2:"baz"}}}]}}.as_json)
  end
  it "should render solr params based on filters" do
    pending "Solr-specific"
    subject.update_attributes filters_attributes:[{field:subject_field, operator:"+", values:["foo","bar"]}, {filter_type:"RESTRICT", field:field2, operator:"-", values:["baz"]}]
    solr_params, user_params = subject.apply_solr_params({}, {})
    solr_params.should == {:fq=>["-field2_ssi:\"baz\"", "subject_ssi:\"foo\" OR subject_ssi:\"bar\""]}
  end
  it "has many members who can belong to many audiences (has and belongs to many)" do
    @identity = FactoryGirl.create(:identity)
    subject.members.should == []
    subject.members << @identity
    subject.members.should == [@identity]
    subject.save
    @identity.audiences.should == [subject]
  end
  it "should accept nested attributes for filters" do
    subject.update_attributes filters_attributes: [{field_name:"title"}, {field_name:"date_created"}, {field_name:"location"}]
    subject.save
    subject.filters.count.should == 3
    f1, f2, f3 = subject.filters
    f1.field_name.should == "location"
    f2.field_name.should == "date_created"
    f3.field_name.should == "title"
    subject.update_attributes filters_attributes: [{id: f2.id, "_destroy"=>"1"}]
    subject.filters.count.should == 2
    subject.filters.should == [f1, f3]
  end
  it "should accept token list for associating members" do
    @identity1 = FactoryGirl.create :identity
    @identity2 = FactoryGirl.create :identity
    subject.save
    subject.update_attributes member_ids: [@identity2.id, @identity1.id]
    subject.save
    subject.members.first.should == @identity2.reload
    subject.members[1].should == @identity1.reload
    subject.update_attributes member_ids: [@identity1.id]
    subject.members.count.should == 1
    subject.members.should == [@identity1]
  end
  describe "json" do
    before do
      @identity1 = FactoryGirl.create :identity
      @identity2 = FactoryGirl.create :identity
      @category = FactoryGirl.create :audience_category
      @category.audiences << subject
      subject.save
    end
    it "should include filters and members" do
      subject.update_attributes name: "The Audience", description:"A description", filters_attributes:[{field_name:"field1"}, {field_name:"field2"}], member_ids:[ @identity2.id, @identity1.id]
      subject.as_json["name"].should == "The Audience"
      subject.as_json["description"].should == "A description"
      subject.as_json["audience_category_id"].should == @category.id
      subject.filters.count.should == 2
      subject.members.count.should == 2
      subject.as_json["filters"].should == subject.filters.as_json
      subject.as_json["member_ids"].should == subject.member_ids
    end
  end
end
