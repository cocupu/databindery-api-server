require 'rails_helper'

describe Api::V1::PoolsController do
  before do
    @identity = FactoryGirl.create :identity
    @my_pool = FactoryGirl.create :pool, :owner=>@identity
    @not_my_pool = FactoryGirl.create(:pool)
  end
  describe "index" do
    describe "when not logged on" do
      subject { get :index, identity_id: @identity.short_name }
      it "should show nothing" do
        expect(response).to be_successful
        expect(assigns[:pools]).to be_nil
      end
    end

    describe "when logged on" do
      before do
        sign_in @identity.login_credential
      end
      it "should be successful" do
        get :index
        expect(response).to be_successful
        expect(assigns[:pools]).to eq [@my_pool]
      end
      it "should return json" do
        get :index, identity_id: @identity.short_name, format: :json
        expect(response).to  be_successful
        expect(JSON.parse(response.body)).to eq [{"short_name"=>@my_pool.short_name, "name"=>@my_pool.name, "description"=>nil, "identity"=>@identity.short_name, "url"=>"/api/v1/pools/#{@my_pool.id}"}]
      end
      it "should allow searching by identity short name" do
        get :index, identity_id: @identity.short_name
        expect(response).to  be_successful
        expect(assigns[:pools]).to eq [@my_pool]
      end
    end
  end

  describe "show" do
    describe "when not logged on" do
      it "should redirect to root" do
        get :show, id: @my_pool, identity_id: @identity.short_name
        expect(response).to respond_unauthorized
      end
    end

    describe "when logged on" do
      before do
        sign_in @identity.login_credential
        @my_model = FactoryGirl.create(:model, pool: @identity.pools.first)
        @other_pool = FactoryGirl.create(:pool, owner: @identity)
        @my_model_different_pool = FactoryGirl.create(:model, pool: @other_pool)
        @not_my_model = FactoryGirl.create(:model)
      end
      describe "requesting a pool I don't own" do
        it "should not get access" do
          get :show, :id=>@not_my_pool, identity_id: @identity.short_name
          expect(response).to respond_forbidden
        end
      end
      describe "requesting a pool I own" do
        it "should be successful" do
          get :show, :id=>@my_pool.id
          expect(response.body).to eq( @my_pool.to_json)
        end
        it "should allow requests to use short_name" do
          get :show, :id=>@my_pool.short_name
          expect(response.body).to eq( @my_pool.to_json)
        end
      end
      describe "requesting a pool I can edit" do
        before do
          @other_identity = FactoryGirl.create(:identity)
          AccessControl.create!(:pool=>@my_pool, :identity=>@other_identity, :access=>'EDIT')
        end
        it "should be successful when rendering json" do
          get :show, :id=>@my_pool, :format=>:json, identity_id: @identity.short_name
          expect(response.body).to eq( @my_pool.to_json)
          json = JSON.parse(response.body)
          expect(json['access_controls']).to eq [{'identity' => @other_identity.id, 'access'=>'EDIT'} ]
        end
      end
    end
  end

  describe "create" do
    describe "when not logged on" do
      it "should redirect to home" do
        post :create, :pool=>{:name=>"New Pool"}, identity_id: @identity.short_name
        expect(response).to respond_unauthorized
      end
    end

    describe "when logged on" do
      before do
        sign_in @identity.login_credential
      end
      it "should be successful when rendering json" do
        post :create, :pool=>{:name=>"New Pool", :short_name=>'new_pool'}, :format=>:json, identity_id: @identity.short_name
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json['owner_id']).to eq @identity.id
        expect(json['name']).to eq "New Pool"
        expect(json['short_name']).to eq "new_pool"
      end
      it "should set the currently logged in identity as owner of the new pool if no identity_id is provided" do
        post :create, :pool=>{:name=>"New Pool", :short_name=>'new_pool'}, :format=>:json
        expect(response).to be_successful
        expect(assigns[:pool].owner).to eq @identity
      end
      it "should give an error when attempting to create pools for identity that you don't own" do
        post :create, :pool=>{:name=>"New Pool", :short_name=>'new_pool'}, :format=>:json, identity_id: FactoryGirl.create(:identity).short_name
        expect(response).to respond_forbidden(description:"You can't create for that identity")
      end
    end
  end

  describe "update" do
    describe "when not logged on" do
      it "should redirect to home" do
        put :update, :pool=>{:name=>"New Pool"}, identity_id: @identity.short_name, :id=>@my_pool
        expect(response).to respond_unauthorized
      end
    end

    describe "when logged on" do
      before do
        @another_identity = FactoryGirl.create(:identity)
        @another_identity2 = FactoryGirl.create(:identity)
        sign_in @identity.login_credential
      end
      it "should be successful when rendering json" do
        put :update, :pool=>{:name=>"ReName", :short_name=>'updated_pool', 
            :access_controls=>[{identity: @another_identity.short_name, access: 'EDIT'},
                {identity: @another_identity2.short_name, access: 'NONE'}]},
            :format=>:json, :id=>@my_pool
        expect(response).to  be_successful
        @my_pool.reload
        expect(@my_pool.owner).to eq @identity
        expect(@my_pool.name).to eq "ReName"
        expect(@my_pool.short_name).to eq "updated_pool"
        expect(@my_pool.access_controls.size).to eq 1
        expect(@my_pool.access_controls.first.identity).to eq @another_identity
        expect(@my_pool.access_controls.first.access).to eq "EDIT"
      end
      it "should support submission of json without :pool hash" do
        put :update, :access_controls=>[{identity: @another_identity.short_name, access: 'EDIT'},
                                        {identity: @another_identity2.short_name, access: 'NONE'}],
                      :name=>"ReName", :short_name=>'updated_pool',
            :format=>:json, :id=>@my_pool
        expect(response).to be_successful
        @my_pool.reload
        expect(@my_pool.owner).to eq @identity
        expect(@my_pool.name).to eq "ReName"
        expect(@my_pool.short_name).to eq "updated_pool"
        expect(@my_pool.access_controls.size).to eq 1
        expect(@my_pool.access_controls.first.identity).to eq @another_identity
        expect(@my_pool.access_controls.first.access).to eq "EDIT"
      end
      it "should forbid updating pool if user does not have permission" do
        put :update, :pool=>{:name=>"New Pool", :short_name=>'new_pool'}, :format=>:json, :id=>@not_my_pool
        expect(response).to respond_forbidden
      end
    end
  end
end
