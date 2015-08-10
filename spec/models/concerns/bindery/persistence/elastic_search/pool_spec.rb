require  'rails_helper'

describe Bindery::Persistence::ElasticSearch::Pool do

  subject{ FactoryGirl.create(:pool) }
  let(:elasticsearch) { Bindery::Persistence::ElasticSearch.client }

  it "creates a corresponding elasticsearch index", elasticsearch:true do
    expect(elasticsearch.indices.get(index: "#{subject.to_param}*", expand_wildcards: 'open').count).to eq 1
  end

  # See: http://www.elasticsearch.org/blog/changing-mapping-with-zero-downtime/
  it "uses aliases, allowing for indexes to be rebuilt and swapped transparently", elasticsearch:true do
    expect( elasticsearch.indices.get_alias(index: "#{subject.to_param}*", name: subject.to_param).count).to eq 1
  end

  describe 'destroy' do
    it "destroys the elasticsearch index and alias", elasticsearch:true do
      subject.destroy
      allow(subject).to receive(:delete_bucket)
      expect(elasticsearch.indices.get(index: "#{subject.to_param}*", expand_wildcards: 'open').count).to eq 0
      expect{ elasticsearch.indices.get_alias(name: subject.id).count }.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
    end
  end

  it "delegates search to the adapter" do
    query_params = {foo:"bar"}
    expect(subject.__elasticsearch__).to receive(:search).with(query_params)
    subject.search(query_params)
  end
  describe "Adapter.search", elasticsearch:true do
    let(:pool) { double("Pool", to_param:"4567") }
    let(:stub_response){ {"hits"=>{"hits"=>[]}} }
    subject { Bindery::Persistence::ElasticSearch::Pool::Adapter.new(pool) }

    it "queries the corresponding elasticsearch index" do
      expect(elasticsearch).to receive(:search).with({index:pool.to_param, type:"241", body: {query:{match:{"subject"=>"Tornadoes"}}}.as_json}).and_return(stub_response)
      subject.search(type:"241", body: {query:{match:{"subject"=>"Tornadoes"}}})
    end
    it "accepts a query_builder" do
      query_builder = Bindery::Persistence::ElasticSearch::Query::QueryBuilder.new
      expect(query_builder).to receive(:index=).with(pool.to_param).at_least(:once)
      expect(elasticsearch).to receive(:search).with(query_builder.as_query).and_return(stub_response)
      subject.search(query_builder)
    end
    it "accepts a Hash of parameters, filters them and applies them to a querybuilder" do
      # overrides the :index param if it was provided.
      allow(elasticsearch).to receive(:search).and_return(stub_response)
      expect(Bindery::Persistence::ElasticSearch::Query::QueryBuilder).to receive(:new).with(index:pool.to_param, body: {query:{match:{"location"=>"Rome"}}}).at_least(:once).and_call_original
      subject.search(index:"another_pool", body: {query:{match:{"location"=>"Rome"}}})
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
        query_builder, user_params = subject.apply_elasticsearch_params_for_identity(@identity)
        expect(query_builder.as_json['body']['query']['filtered']['filter']).to eq({bool:{should:[{query:{match:{'subject'=>'foo'}}},{query:{match:{'subject'=>'bar'}}}],must_not:[{query:{match:{'location'=>'baz'}}}]}}.as_json)
      end
    end
  end
end