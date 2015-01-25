require 'rails_helper'

describe Api::V1::ExhibitsController do

  before do
    @identity = FactoryGirl.create :identity
    @pool = FactoryGirl.create :pool, :owner=>@identity
    @exhibit = FactoryGirl.build(:exhibit, pool: @pool)
    @exhibit.facets = ['f2']
    @exhibit.save!
    @exhibit2 = FactoryGirl.create(:exhibit, :pool=>FactoryGirl.create(:pool, :owner=>@identity)) #should not show this exhibit in index.
    @model1 = FactoryGirl.create(:model, :name=>"Mods and Rockers", :pool=>@exhibit.pool, fields_attributes: [{code: 'f1', name: 'Field good'}, {code: 'f2', name: "Another one"}])
    @model2 = FactoryGirl.create(:model, :pool=>@exhibit.pool, fields_attributes: [{code: 'style', name: 'Style'}, {code: 'label', name: "Label"}, {code: 'f2', name: "Another one"}])
  end

  describe "when signed in" do
    before do
      sign_in @identity.login_credential
    end
    describe "index" do
      it "should be success" do
        get :index, :pool_id=>@pool, :identity_id=>@identity.short_name
        expect(response).to be_success
        expect(response.body).to eq(assigns[:exhibits].to_json)
        assigns[:pool].should == @pool
        assigns[:exhibits].should ==[@exhibit]
        assigns[:exhibits].should_not include @exhibit2
      end
    end

    describe "create" do
      it "should be success and render json" do
        post :create, :pool_id=>@pool, :identity_id=>@identity.short_name, :exhibit=> {:title => 'Foresooth', :facets=>['looketh', 'overmany', 'thither'] }
        expect(response).to be_success
        expect(response.body).to eq(assigns[:exhibit].to_json)
        assigns[:exhibit].facets.should == ['looketh', 'overmany', 'thither']
      end
      it "should not allow create for a pool you don't own" do
        post :create, pool_id: FactoryGirl.create(:pool), identity_id: @identity.short_name, :exhibit=> {:title => 'Foresooth', :facets=>'looketh, overmany, thither' }
        expect(response).to be_forbidden
      end
    end

    describe "update" do
      it "should be success and render json" do
        put :update, :id=>@exhibit.id, :exhibit=> {:title => 'Foresooth', :facets=>['looketh', 'overmany', 'thither'], :index_fields=>['title', 'author', 'call_number'] }, :pool_id=>@pool, :identity_id=>@identity.short_name
        expect(response).to be_success
        expect(response.body).to eq(assigns[:exhibit].to_json)
        assigns[:exhibit].facets.should == ['looketh', 'overmany', 'thither']
        assigns[:exhibit].index_fields.should == ['title', 'author', 'call_number']
      end
      it "should update filters" do
        exhibit_attributes = {title: "Test Perspective with Model", filters_attributes:[{"field_name"=>"subject", "operator"=>"+", "values"=>["4", "1"]}, {"field_name"=>"collection_owner", "operator"=>"-", "values"=>["Hannah Severin"]}], :pool_id=>@pool, :identity_id=>@identity.short_name}
        put :update, :id=>@exhibit.id, :exhibit=> exhibit_attributes, :pool_id=>@pool, :identity_id=>@identity.short_name
        expect(response).to be_success
        assigns[:exhibit].filters.count.should == 2
        subject_filter = assigns[:exhibit].filters.where(field_name:"subject").first
        subject_filter.operator.should == "+"
        subject_filter.values.should == ["4", "1"]
        collection_owner_filter = assigns[:exhibit].filters.where(field_name:"collection_owner").first
        collection_owner_filter.operator.should == "-"
        collection_owner_filter.values.should == ["Hannah Severin"]
      end
      it "should not add filters when filters are not fully specified" do
        exhibit_attributes = {title: "Test Perspective with Model", filters_attributes:[{"field_name"=>"model"}, {"field_name"=>"collection_location", "operator"=>"+", "values"=>[""]}], :pool_id=>@pool, :identity_id=>@identity.short_name}
        put :update, :id=>@exhibit.id, :exhibit=> exhibit_attributes, :pool_id=>@pool, :identity_id=>@identity.short_name
        expect(response).to be_success
        assigns[:exhibit].filters.should == []
      end
      it "should add filters for restricting models when restrict_models is checked" do
        exhibit_attributes = {title: "Test Perspective with Model", restrict_models: "1", filters_attributes:[{"field_name"=>"model", "operator"=>"+", "values"=>["4", "1"]}], :pool_id=>@pool, :identity_id=>@identity.short_name}
        put :update, :id=>@exhibit.id, :exhibit=> exhibit_attributes, :pool_id=>@pool, :identity_id=>@identity.short_name
        expect(response).to be_success
        assigns[:exhibit].filters.count.should == 1
        assigns[:exhibit].filters.first.field_name.should == "model"
      end
      it "should not restrict models if restrict_models is not checked" do
        exhibit_attributes = {title: "Test Perspective with Model", filters_attributes:[{"field_name"=>"model", "operator"=>"+", "values"=>["foo", "bar"]}], :pool_id=>@pool, :identity_id=>@identity.short_name}
        put :update, :id=>@exhibit.id, :exhibit=> exhibit_attributes, :pool_id=>@pool, :identity_id=>@identity.short_name
        expect(response).to be_success
        assigns[:exhibit].filters.should == []
      end
    end

  end

  describe "when not signed in" do
    describe "index" do
      it "should be unauthorized" do
        get :index, :pool_id=>@pool, :identity_id=>@identity.short_name
        expect(response).to respond_unauthorized
      end
    end

    describe "create" do
      it "should be unauthorized" do
        post :create, :exhibit=> {:title => 'Foresooth', :facets=>'looketh, overmany, thither' }, :pool_id=>@pool, :identity_id=>@identity.short_name
        expect(response).to respond_unauthorized
      end
    end

    describe "update" do
      it "should be unauthorized" do
        put :update, :id=>@exhibit.id, :exhibit=> {:title => 'Foresooth', :facets=>'looketh, overmany, thither' }, :pool_id=>@pool, :identity_id=>@identity.short_name
        expect(response).to respond_unauthorized
      end
    end

  end


end
