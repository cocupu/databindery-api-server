require 'rails_helper'

describe Api::V1::ExhibitDataController, elasticsearch:true do

  before(:all) do
    Sidekiq::Testing.inline! # Ensure that node Indexers are run in this before(:all) block

    @identity = FactoryGirl.create :identity
    @pool = FactoryGirl.create :pool, :owner=>@identity

    @style_field = Field.create(name:'Style')
    @label_field = Field.create(name:'Label')
    @f1 = Field.create(code: 'f1', name: 'Field good')
    @f2 = Field.create(code: 'f2', name: "Another one")

    @exhibit = FactoryGirl.build(:exhibit, pool: @pool)
    @exhibit.facets = [@f2]
    @exhibit.index_fields = [@f1, @f2]
    @exhibit.save!

    @model1 = FactoryGirl.create(:model, :name=>"Mods and Rockers", :pool=>@exhibit.pool)
    @model1.update_attributes fields: [@f1,@f2]
    @model1.save!
    @model2 = FactoryGirl.create(:model, :pool=>@exhibit.pool)
    @model2.update_attributes fields: [@style_field,@label_field,@f2]
    #TODO ensure that code is unique for all fields in a pool, so that Author.name is separate from Book.name
    @model2.save!

    @instance = Node.new(data: {@f1.to_param => 'bazaar'})
    @instance.model = @model1
    @instance.pool = @exhibit.pool 
    @instance.save!

    @instance.data[@f2.to_param] = 'Bizarre'
    @instance.save! #Create a new version of this, only one version should show in search results.

    @instance2 = Node.new(data: {@f1.to_param => 'bazaar'})
    @instance2.model = @model1
    @instance2.pool = FactoryGirl.create :pool
    @instance2.save!
    sleep 1 # wait for everything to arrive in the elasticsearch index
  end

  let(:style_field) {@style_field}
  let(:label_field) {@label_field}
  let(:f1) {@f1}
  let(:f2) {@f2}

  # let(:subject_field) { FactoryGirl.create(:subject_field) }

  describe "when signed in" do

    before do
      sign_in @identity.login_credential
    end

    describe "index" do
      it "applies filters, fields and facets from exhibit" do
        exhibit_with_filters = FactoryGirl.build(:exhibit, pool: @pool, index_fields:[style_field,@f1], facets:[style_field,@f1], filters_attributes: [field:style_field, operator:"+", values:["test", "barf"]])
        exhibit_with_filters.save!
        get :index, :exhibit_id=>exhibit_with_filters.id, :q=>'bazaar', :pool_id=>@pool
        expect(subject.query_builder.as_json["body"]["aggregations"]).to eq({"style"=>{"terms"=>{"field"=>"style"}}, "f1"=>{"terms"=>{"field"=>"f1"}}})
        expect(subject.query_builder.as_json["body"]["fields"]).to eq(["_id", "_bindery_pool", "_bindery_model", "style","f1"])
        expect(subject.query_builder.as_json["body"]["query"]["filtered"]["filter"]).to eq({bool:{should:[{query:{match:{"style"=>"test"}}},{query:{match:{"style"=>"barf"}}}]}}.as_json)
      end
      it "should be success" do
        get :index, :exhibit_id=>@exhibit.id, :q=>'bazaar', :pool_id=>@pool
        expect(response).to be_successful
        expect(assigns[:exhibit]).to eq @exhibit
        expect(assigns[:document_list].size).to eq 1
      end
    end
  end

  describe "when not signed in" do
    describe "index" do
      it "should not be successful" do
        get :index, :exhibit_id=>@exhibit.id, :q=>'bazaar', :pool_id=>@pool
        expect(response).to respond_unauthorized
      end
    end
  end
end
