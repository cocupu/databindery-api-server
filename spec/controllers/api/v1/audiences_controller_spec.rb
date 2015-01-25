require 'rails_helper'

describe Api::V1::AudiencesController do
  before do
    @identity = FactoryGirl.create :identity
    @another_identity = FactoryGirl.create(:identity)
    @pool = FactoryGirl.create :pool, :owner=>@identity
    @category = FactoryGirl.create :audience_category, :pool=>@pool
    @audience = FactoryGirl.create :audience, :audience_category=>@category
    @pool.audience_categories <<  @category
    @not_my_pool = FactoryGirl.create :pool, owner: @another_identity
  end
  describe "index" do
    describe "when not logged on" do
      subject { get :index, identity_id: @identity.short_name, pool_id: @pool.short_name, audience_category_id:@category }
      it "should show nothing" do
        expect(response).to  be_successful
        assigns[:audiences].should be_nil
      end
    end

    describe "when logged on" do
      before do
        sign_in @identity.login_credential
      end
      it "should be successful" do
        get :index, identity_id: @identity.short_name, pool_id: @pool.short_name, audience_category_id:@category, format: :json
        expect(response).to  be_successful
        assigns[:audiences].should == [@audience]
      end
      it "should return json" do
        get :index, identity_id: @identity.short_name, pool_id: @pool.short_name, audience_category_id:@category, format: :json
        response.should be_successful
        json = JSON.parse(response.body)
        json.first.delete("created_at")
        json.first.delete("updated_at")
        json.should == [{"audience_category_id"=>@category.id, "description"=>"MyText", "id"=>@audience.id, "name"=>"MyString", "position"=>nil, "filters"=>[], "member_ids"=>[],  "pool_name"=>@pool.short_name, "identity_name"=>@identity.short_name}]
      end
    end
  end

  describe "show" do
    describe "when not logged on" do
      it "should require authentication" do
        get :show, id: @audience, identity_id: @identity.short_name, pool_id: @pool.short_name, audience_category_id:@category
        expect(response).to respond_unauthorized
      end
    end

    describe "when logged on" do
      before do
        sign_in @identity.login_credential
        @not_my_category = FactoryGirl.create :audience_category, pool:@not_my_pool
        @not_my_audience = FactoryGirl.create :audience, audience_category:@not_my_category
      end
      describe "requesting an audience in a pool I don't control" do
        it "should forbid action" do
          get :show, :id=>@not_my_audience, identity_id: @identity.short_name, pool_id: @not_my_pool.short_name, audience_category_id:@not_my_category, format: :json
          expect(response).to respond_forbidden
        end
      end
      describe "requesting audiences from a pool I own" do
        it "should be successful when rendering json" do
          get :show, :id=>@audience, identity_id: @identity.short_name, pool_id: @pool, audience_category_id:@category, format: :json
          expect(response).to  be_successful
          json = JSON.parse(response.body)
          json.delete("created_at")
          json.delete("updated_at")
          json.should == {"audience_category_id"=>@category.id, "description"=>"MyText", "id"=>@audience.id, "name"=>"MyString", "position"=>nil, "filters"=>[], "member_ids"=>[],  "pool_name"=>@pool.to_param, "identity_name"=>@identity.short_name}
        end
      end
    end
  end

  describe "create" do
    describe "when not logged on" do
      it "should require authentication" do
        post :create, :audience=>{:name=>"New Audience"}, identity_id: @identity.short_name, pool_id: @pool.short_name, audience_category_id:@category
        expect(response).to respond_unauthorized
      end
    end

    describe "when logged on" do
      before do
        sign_in @identity.login_credential
      end
      it "should be successful when rendering json" do
        post :create, :audience=>{:name=>"New Audience", description:"A Description"}, :format=>:json, identity_id: @identity.short_name, pool_id: @pool.short_name, audience_category_id:@category
        expect(response).to  be_successful
        json = JSON.parse(response.body)
        json["audience_category_id"].should == @category.id
        json['name'].should == "New Audience"
        json['description'].should == "A Description"
      end
    end
  end

  describe "update" do
    describe "when not logged on" do
      it "should require authentication" do
        put :update, :audience=>{:name=>"New Audience"}, identity_id: @identity.short_name, :id=>@audience, pool_id: @pool.short_name, audience_category_id:@category
        expect(response).to respond_unauthorized
      end
    end

    describe "when logged on" do
      before do
        @another_identity2 = FactoryGirl.create(:identity)
        sign_in @identity.login_credential
        @not_my_category = FactoryGirl.create :audience_category, :pool=>@not_my_pool
        @not_my_audience = FactoryGirl.create :audience, audience_category:@not_my_category
      end
      it "should be successful when rendering json" do
        put :update, :audience=>{name: "ReName", description:"New Description"},
            :format=>:json, identity_id: @identity.short_name, :id=>@audience, pool_id:@pool.short_name, audience_category_id:@category
        expect(response).to  be_successful
        @audience.reload
        @audience.name.should == "ReName"
        @audience.description.should == "New Description"
      end
      it "should allow you to update filters from a json property called filters (not filters_attributes)" do
        put :update, audience:{"description"=>"New description", "id"=>@audience.id, "name"=>"The Category", "filters"=>[{"field_name"=>"title", "values"=>["Title 1","Title 3"]}, {"field_name"=>"date_created"}, {"field_name"=>"date_updated"}]},
            :format=>:json, identity_id: @identity.short_name, :id=>@audience, pool_id:@pool.short_name, audience_category_id:@category
        expect(response).to  be_successful
        @audience.reload
        @audience.description.should == "New description"
        @audience.name.should == "The Category"
        @audience.filters.count.should == 3
        title_filter = @audience.filters.where(field_name: "title").first
        title_filter.values.should == ["Title 1","Title 3"]
        put :update, audience:{"filters"=>[{"id"=>title_filter.id, "_destroy"=>"1"}]},
            :format=>:json, identity_id: @identity.short_name, :id=>@audience, pool_id:@pool.short_name, audience_category_id:@category
        @audience.reload
        @audience.filters.count.should == 2
        @audience.filters.where(field_name: "title").should be_empty
      end
      it "should support submission of json objects without :audience hash" do
        # when submitting json pool info, filters isn't being copied into params[:audience].
        # This test makes sure that the controller handles that case.
        put :update, :filters=>[{"field_name"=>"title"}, {"field_name"=>"date_created"}, {"field_name"=>"date_updated"}],
            :format=>:json, identity_id: @identity.short_name, :id=>@audience, pool_id:@pool.short_name, audience_category_id:@category
        expect(response).to  be_successful
        @audience.reload
        @audience.filters.count.should == 3
      end
      it "should give an error when don't have edit powers on the category (or its pool)" do
        put :update, :audience=>{:name=>"Rename"}, :format=>:json, identity_id: @another_identity.short_name, :id=>@not_my_audience, pool_id: @pool.short_name, audience_category_id:@not_my_category
        expect(response).to respond_forbidden
      end
    end
  end
end
