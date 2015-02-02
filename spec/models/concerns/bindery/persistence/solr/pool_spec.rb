require 'rails_helper'

describe Bindery::Persistence::Solr::SearchFilter do

  before do
    Node.include Bindery::Persistence::Solr::Node
    Pool.include Bindery::Persistence::Solr::Pool
    SearchFilter.include Bindery::Persistence::Solr::SearchFilter
  end

  subject { Pool.new }

  describe "audiences" do
    let(:subject_field) {FactoryGirl.create(:subject_field)}
    let(:location_field) {FactoryGirl.create(:location_field)}
    before do
      @identity = FactoryGirl.create :identity
      @cat1 =  FactoryGirl.create :audience_category, pool:subject
      @cat2 =  FactoryGirl.create :audience_category
      @aud1 =  FactoryGirl.create :audience, audience_category:@cat1, name:"Audience 1"
      @aud2 =  FactoryGirl.create :audience, audience_category:@cat1, name:"Audience 2"
      @aud3 =  FactoryGirl.create :audience, audience_category:@cat2, name:"Audience 3"
      @aud1.members << @identity
      @aud3.members << @identity
      subject.audience_categories << @cat1 << @cat2
    end
    describe "apply_query_params_for_identity" do
      it "aliases to apply_solr_params_for_identity" do
        expect(subject).to receive(:apply_solr_params_for_identity)
        subject.apply_query_params_for_identity(@identity, {}, {})
      end
    end
    describe "apply_solr_params_for_identity" do
      it "should aggregate solr_params from all applicable audiences" do
        @aud1.update_attributes filters_attributes:[{field:subject_field, operator:"+", values:["foo","bar"]}]
        @aud3.update_attributes filters_attributes:[{field:location_field, filter_type:"RESTRICT", operator:"-", values:["baz"]}]
        solr_params, user_params = subject.apply_solr_params_for_identity(@identity, {}, {})
        solr_params.should == {fq: ["-location_ssi:\"baz\"", "subject_ssi:\"foo\" OR subject_ssi:\"bar\""]}
      end
    end
  end
end
