require 'rails_helper'

describe Api::V1::AudienceCategoriesController do
  before do
    stub_elasticsearch
    @identity = FactoryGirl.create :identity
    @another_identity = FactoryGirl.create(:identity)
    @pool = FactoryGirl.create :pool, :owner=>@identity
    @category = FactoryGirl.create :audience_category, :pool=>@pool
    @pool.audience_categories <<  @category
    @not_my_pool = FactoryGirl.create :pool, owner: @another_identity
  end
  describe "index" do
    describe "when not logged on" do
      subject { get :index, identity_id: @identity.short_name, pool_id: @pool.id }
      it "should show nothing" do
        expect(response).to  be_successful
        assigns[:pools].should be_nil
      end
    end

    describe "when logged on" do
      before do
        sign_in @identity.login_credential
      end
      it "should be successful" do
        get :index, identity_id: @identity.short_name, pool_id: @pool.id, format: :json
        expect(response).to  be_successful
        assigns[:audience_categories].should == [@category]
      end
      it "should return json" do
        get :index, identity_id: @identity.id, pool_id: @pool.id, format: :json
        response.should be_successful
        json = JSON.parse(response.body)
        json.first.delete("created_at")
        json.first.delete("updated_at")
        json.should == [{"description"=>"MyText", "id"=>@category.id, "name"=>"MyString", "pool_id"=>@pool.id.to_s, "audiences"=>[], "identity_id"=>@identity.id}]
      end
    end
  end

  describe "show" do
    describe "when not logged on" do
      it "should require authentication" do
        get :show, id: @category, identity_id: @identity.short_name, pool_id: @pool.id
        expect(response).to respond_unauthorized
      end
    end

    describe "when logged on" do
      before do
        sign_in @identity.login_credential
        @not_my_category = FactoryGirl.create :audience_category, :pool=>@not_my_pool
      end
      describe "requesting a pool I don't own" do
        it "should forbid action" do
          get :show, :id=>@not_my_category, identity_id: @identity.short_name, pool_id: @not_my_pool.short_name, format: :json
          expect(response).to respond_forbidden
        end
      end
      describe "requesting audience categories from a pool I own" do
        it "should be successful when rendering json" do
          get :show, :id=>@category, identity_id: @identity.id, pool_id: @pool, format: :json
          expect(response).to  be_successful
          json = JSON.parse(response.body)
          json.delete("created_at")
          json.delete("updated_at")
          json.should == {"description"=>"MyText", "id"=>@category.id, "name"=>"MyString", "pool_id"=>@pool.id.to_s, "audiences"=>[], "identity_id"=>@identity.id}
        end
      end
    end
  end

  describe "create" do
    describe "when not logged on" do
      it "should require authentication" do
        post :create, :audience_category=>{:name=>"New Category"}, identity_id: @identity.short_name, pool_id: @pool.id
        expect(response).to respond_unauthorized
      end
    end

    describe "when logged on" do
      before do
        sign_in @identity.login_credential
      end
      it "should be successful when rendering json" do
        post :create, :audience_category=>{:name=>"New Category", description:"A Description"}, :format=>:json, identity_id: @identity.short_name, pool_id: @pool.id
        expect(response).to  be_successful
        json = JSON.parse(response.body)
        json["pool_id"].should == @pool.id.to_s
        json['name'].should == "New Category"
        json['description'].should == "A Description"
      end
    end
  end

  describe "update" do
    describe "when not logged on" do
      it "should require authentication" do
        put :update, :audience_category=>{:name=>"New Category"}, identity_id: @identity.short_name, :id=>@category, pool_id: @pool.id
        expect(response).to respond_unauthorized
      end
    end

    describe "when logged on" do
      before do
        @another_identity2 = FactoryGirl.create(:identity)
        sign_in @identity.login_credential
        @not_my_category = FactoryGirl.create :audience_category, :pool=>@not_my_pool
      end
      it "should be successful when rendering json" do
        put :update, :audience_category=>{name: "ReName", description:"New Description"},
            :format=>:json, identity_id: @identity.short_name, :id=>@category, pool_id:@pool.id
        expect(response).to  be_successful
        @category.reload
        @category.name.should == "ReName"
        @category.description.should == "New Description"
      end
      it "should allow you to update audiences from a json property called audiences (not audiences_attributes)" do
        put :update, audience_category:{"description"=>"New description", "id"=>@category.id, "name"=>"The Category", "audiences"=>[{"description"=>nil, "name"=>"Level One", "position"=>nil}, {"description"=>nil, "name"=>"Level Two", "position"=>nil}, {"name"=>"Other Level"}]},
            :format=>:json, identity_id: @identity.short_name, :id=>@category, pool_id:@pool.id
        expect(response).to  be_successful
        @category.reload
        @category.description.should == "New description"
        @category.name.should == "The Category"
        @category.audiences.count.should == 3
        other_audience = @category.audiences.where(name: "Other Level").first
        put :update, audience_category:{"audiences"=>[{"id"=>other_audience.id, "_destroy"=>"1"}]},
            :format=>:json, identity_id: @identity.short_name, :id=>@category, pool_id:@pool.id
        @category.reload
        @category.audiences.count.should == 2
        @category.audiences.where(name: "Other Level").should be_empty
      end
      it "should allow you to post json objects that are not wrapped in :audience_category hash" do
        put :update, "description"=>"New description", "id"=>@category.id, "name"=>"The Category", "audiences"=>[{"description"=>nil, "name"=>"Level One", "position"=>nil}, {"description"=>nil, "name"=>"Level Two", "position"=>nil}, {"name"=>"Other Level"}],
            :format=>:json, identity_id: @identity.short_name, :id=>@category, pool_id:@pool.id
        expect(response).to  be_successful
        @category.reload
        @category.description.should == "New description"
        @category.name.should == "The Category"
        @category.audiences.count.should == 3
        other_audience = @category.audiences.where(name: "Other Level").first
        put :update, audience_category:{"audiences"=>[{"id"=>other_audience.id, "_destroy"=>"1"}]},
            :format=>:json, identity_id: @identity.short_name, :id=>@category, pool_id:@pool.id
        @category.reload
        @category.audiences.count.should == 2
        @category.audiences.where(name: "Other Level").should be_empty
      end
      it "should give an error when don't have edit powers on the category (or its pool)" do
        put :update, :audience_category=>{:name=>"Rename"}, :format=>:json, identity_id: @another_identity.short_name, :id=>@not_my_category, pool_id: @pool.id
        expect(response).to respond_forbidden
      end
    end
  end
end
