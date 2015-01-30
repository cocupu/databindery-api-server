require 'rails_helper'

describe Api::V1::FieldsController do
  before do
    @identity = FactoryGirl.create :identity
    @pool = FactoryGirl.create :pool, :owner=>@identity
    @my_model = FactoryGirl.create(:model, pool: @pool)
    @not_my_model = FactoryGirl.create(:model)
  end
  describe "create" do
    describe "when not logged on" do
      it "should require authentication" do
        post :create, :model_id=>@my_model.id
        expect(response).to respond_unauthorized
      end
    end

    describe "when logged on" do
      before do
        sign_in @identity.login_credential
      end
      it "should forbid access on a model that's not mine " do
        post :create, :model_id=>@not_my_model.id
        expect(response).to respond_forbidden
      end
      it "should create and redirect" do
        post :create, :model_id=>@my_model.id, :field=>{name: 'Event Date', type: 'DateField', uri: 'dc:date', multivalue: true}
        expect(response).to be_successful
        @my_model.reload
        @my_model.fields.count.should == 2
        @my_model.fields.first.code.should == "description"
        new_field = @my_model.fields.last
        new_field.code.should == "event_date"
        new_field.name.should == "Event Date"
        new_field.type.should == "DateField"
        new_field.uri.should == "dc:date"
        new_field.multivalue.should == true
      end
      it "should render json" do
        post :create, :model_id=>@my_model.id, :field=>{name: 'Event Date', type: 'DateField', uri: 'dc:date', multivalue: true}
        @my_model.reload
        @my_model.fields.count.should == 2
        @my_model.fields.first.code.should == "description"
        new_field = @my_model.fields.last
        new_field.code.should == "event_date"
        new_field.name.should == "Event Date"
        new_field.type.should == "DateField"
        new_field.uri.should == "dc:date"
        new_field.multivalue.should == true
        expect(response).to be_successful
      end
    end
  end

  describe "index" do
    describe "when not logged on" do
      it "should require authentication" do
        get :index, identity_id: @identity.short_name, :pool_id=>@pool
        expect(response).to respond_unauthorized
      end
    end
    describe "when I cannot edit the pool" do
      before do
        @another_identity = FactoryGirl.create(:identity)
        sign_in @another_identity.login_credential
      end
      it "should forbid access" do
        get :index, identity_id: @identity.short_name, :pool_id=>@pool
        expect(response).to respond_forbidden
      end
    end
    describe "when I can edit the pool" do
      before do
        sign_in @identity.login_credential
      end
      it "should be successful when rendering json" do
        get :index, identity_id: @identity.short_name, :pool_id=>@pool.id, format: :json
        expect(response).to be_successful
        assigns[:fields].should == @pool.all_fields
        json = JSON.parse(response.body)
        json.should == JSON.parse(@pool.all_fields.to_json)
      end
    end
  end

  describe "show" do
    before do
      @field = Field.create(:code=>'title', :name=>'Title', :type=>'TextField', :uri=>'dc:name', :multivalue=>true)
      @my_model.fields << @field
      @my_model.save
    end
    describe "when not logged on" do
      it "should require authentication" do
        get :show, identity_id: @identity.short_name, :pool_id=>@pool, id:@field.code
        expect(response).to respond_unauthorized
      end
    end
    describe "when I cannot edit the pool" do
      before do
        @another_identity = FactoryGirl.create(:identity)
        sign_in @another_identity.login_credential
      end
      it "should forbid access" do
        get :show, identity_id: @identity.short_name, :pool_id=>@pool, id:@field.code
        expect(response).to respond_forbidden
      end
    end
    describe "when I can edit the pool" do
      before do
        sign_in @identity.login_credential
      end
      it "should return field info and current values from pool" do
        FactoryGirl.create(:node, pool:@pool, model:@my_model, data:{@field.to_param=>"My title"})
        get :show, identity_id: @identity.short_name, :pool_id=>@pool.id, id:@field.code, format: :json
        expect(response).to be_successful
        assigns[:field].should == @field
        json = JSON.parse(response.body)
        json.should == JSON.parse(@field.as_json.merge("numDocs"=>1, "values"=>[{"value"=>"My title", "count"=>1}]).to_json)
      end
    end
  end
end