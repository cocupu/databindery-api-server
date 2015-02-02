require  'rails_helper'

describe Bindery::Persistence::ElasticSearch::Pool, elasticsearch:true do

  subject{ FactoryGirl.create(:pool) }
  let(:elastic_search) { Bindery::Persistence::ElasticSearch.client }

  it "creates a corresponding elasticsearch index" do
    expect(elasticsearch.indices.get(index: "#{subject.to_param}*", expand_wildcards: 'open').count).to eq 1
  end

  # See: http://www.elasticsearch.org/blog/changing-mapping-with-zero-downtime/
  it "uses aliases, allowing for indexes to be rebuilt and swapped transparently" do
    expect( elasticsearch.indices.get_alias(index: "#{subject.to_param}*", name: subject.to_param).count).to eq 1
  end

  describe 'destroy' do
    it "destroys the elasticsearch index and alias" do
      subject.destroy
      expect(elasticsearch.indices.get(index: "#{subject.to_param}*", expand_wildcards: 'open').count).to eq 0
      expect{ elasticsearch.indices.get_alias(name: subject.id).count }.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
    end
  end

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
      it "aliases to apply_elasticsearch_params_for_identity" do
        expect(subject).to receive(:apply_elasticsearch_params_for_identity)
        subject.apply_query_params_for_identity(@identity, {}, {})
      end
    end
    describe "apply_elasticsearch_params_for_identity" do
      it "should aggregate elasticsearch_params from all applicable audiences" do
        @aud1.update_attributes filters_attributes:[{field:subject_field, operator:"+", values:["foo","bar"]}]
        @aud3.update_attributes filters_attributes:[{field:location_field, filter_type:"RESTRICT", operator:"-", values:["baz"]}]
        query_params, user_params = subject.apply_elasticsearch_params_for_identity(@identity, {}, {})
        query_params.should == {fq: ["-location:\"baz\"", "subject:\"foo\" OR subject:\"bar\""]}
      end
    end
  end
end