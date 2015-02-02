require 'rails_helper'

describe Api::V1::ExhibitDataController do

  let(:style_field) {Field.create(name:'Style')}
  let(:label_field) {Field.create(name:'Label')}
  let(:f1) {Field.create(code: 'f1', name: 'Field good')}
  let(:f2) {Field.create(code: 'f2', name: "Another one")}

  before do
    @identity = FactoryGirl.create :identity
    @pool = FactoryGirl.create :pool, :owner=>@identity
    @exhibit = FactoryGirl.build(:exhibit, pool: @pool)
    @exhibit.facets = ['f2']
    @exhibit.index_fields = ['f1', 'f2']
    @exhibit.save!

    @model1 = FactoryGirl.create(:model, :name=>"Mods and Rockers", :pool=>@exhibit.pool)

    @model1.update_attributes fields: [f1,f2]
    @model1.save!
    @model2 = FactoryGirl.create(:model, :pool=>@exhibit.pool)
    @model2.update_attributes fields: [style_field,label_field,f2]

    #TODO ensure that code is unique for all fields in a pool, so that Author.name is separate from Book.name
    @model2.save!
    ## Clear out old results so we start from scratch
    raw_results = Bindery.solr.get 'select', :params => {:q => '{!lucene}model_name:"Mods and Rockers"', :fl=>'id', :qt=>'document', :qf=>'model', :rows=>100}
    Bindery.solr.delete_by_id raw_results["response"]["docs"].map{ |d| d["id"]}
    raw_results = Bindery.solr.get 'select', :params => {:q => 'bazaar', :fl=>'id', :qf=>'field_good_s'}
    Bindery.solr.delete_by_id raw_results["response"]["docs"].map{ |d| d["id"]}
    Bindery.solr.commit

    @instance = Node.new(data: {f1.to_param => 'bazaar'})
    @instance.model = @model1
    @instance.pool = @exhibit.pool 
    @instance.save!

    @instance.data[f2.to_param] = 'Bizarre'
    @instance.save! #Create a new version of this, only one version should show in search results.

    @instance2 = Node.new(data: {f1.to_param => 'bazaar'})
    @instance2.model = @model1
    @instance2.pool = FactoryGirl.create :pool
    @instance2.save!

  end

  describe "when signed in" do

    before do
      sign_in @identity.login_credential
    end

    describe "index" do
      it "should apply filters and facets from exhibit" do
        exhibit_with_filters = FactoryGirl.build(:exhibit, pool: @pool, filters_attributes: [field:FactoryGirl.create(:subject_field), operator:"+", values:["test", "barf"]])
        exhibit_with_filters.save!
        get :index, :exhibit_id=>exhibit_with_filters.id, :q=>'bazaar', :pool_id=>@pool
        #user_params = {:exhibit_id=>exhibit_with_filters.id, :q=>'bazaar', :identity_id=>@identity.short_name}
        subject.solr_search_params[:fq].should include('subject_ssi:"test" OR subject_ssi:"barf"')
      end
      it "should convert sort field names to solr fieldnames" do
        field1 = @model1.fields.first
        field2 = @model1.fields[1]
        get :index, :exhibit_id=>@exhibit.id, :q=>'', sort_fields:[{field_id:field1.id,direction:"asc"},{field_id:field2.id,direction:"desc"}], :pool_id=>@pool
        expect(subject.solr_search_params[:sort]).to eq("#{field1.field_name_for_index} asc,#{field2.field_name_for_index} desc")
      end
    end
    describe "show" do
      it "should be success" do
        get :index, :exhibit_id=>@exhibit.id, :q=>'bazaar', :pool_id=>@pool
        assigns[:document_list].size.should == 1
        assigns[:exhibit].should == @exhibit
        assigns[:response]['facet_counts']['facet_fields'].should == {"f2_sim"=>["Bizarre", 1]}
        response.should be_successful
      end
    end
  end
  describe "when not signed in" do
    describe "show" do
      it "should be successful" do
        get :index, :exhibit_id=>@exhibit.id, :q=>'bazaar', :pool_id=>@pool
        assigns[:document_list].size.should == 1
        assigns[:exhibit].should == @exhibit
        assigns[:response]['facet_counts']['facet_fields'].should == {"f2_sim"=>["Bizarre", 1]}
        response.should be_successful
      end
    end
  end
end
