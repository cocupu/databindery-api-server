require 'rails_helper'

describe Api::V1::FileEntitiesController do
  let(:identity2) { FactoryGirl.create(:identity) }
  before do
    @identity = FactoryGirl.create :identity
    @pool = FactoryGirl.create :pool, :owner=>@identity
  end
  describe 'create' do
    before do
      sign_in @identity.login_credential
    end
    it "should create and return json" do
      FileEntity.should_receive(:register).with(@pool, {"binding"=>'1231249'}) {Node.new(pool:@pool, model:Model.file_entity)}
      post :create, :format=>:json, :pool_id=>@pool.short_name, :identity_id=>@identity.short_name, file: {:binding=>'1231249'}
      response.should be_successful
      json = JSON.parse(response.body)
      json.keys.should include('id')
    end
    describe "if target_node provided" do
      before do
        @node_to_target = FactoryGirl.create(:node, pool: @pool)
      end
      it "should add to file list of target_node" do
        # Need to return a persisted Node from stubbed FileEntity.register so it can be added to the target node
        FileEntity.should_receive(:register).with(@pool, {"binding"=>'1231249'}) {FactoryGirl.create(:node, pool:@pool, model:Model.file_entity)}
        post :create, :format=>:json, :pool_id=>@pool.short_name, :target_node_id=>@node_to_target.persistent_id, file: {:binding=>'1231249'}
        target_node = Node.latest_version(@node_to_target.persistent_id)
        target_node.files.last.should == assigns[:file_entity]
      end
    end
    it "should work with info posted by S3 Direct Upload" do
      params_from_s3_direct_upload = {:pool_id=>@pool.short_name, :identity_id=>@identity.short_name, "url"=>"https://s3.amazonaws.com/f542aab0-66e4-0130-8d40-442c031da886/uploads%2F20130305T1425Z_eaf29caae12b6d4a101297b45c46dc2a%2FDSC_0549-3.jpg", "filepath"=>"/f542aab0-66e4-0130-8d40-442c031da886/uploads%2F20130305T1425Z_eaf29caae12b6d4a101297b45c46dc2a%2FDSC_0549-3.jpg", "filename"=>"DSC_0549-3.jpg", "filesize"=>"471990", "filetype"=>"image/jpeg", "binding"=>"https://s3.amazonaws.com/f542aab0-66e4-0130-8d40-442c031da886/uploads%2F20130305T1425Z_eaf29caae12b6d4a101297b45c46dc2a%2FDSC_0549-3.jpg"}
      # There's not actually an object in s3 for this test, so capture the attempt to update its metadata
      S3Connection.any_instance.stub(:get).and_return(double(:metadata=>{}))
      post :create, params_from_s3_direct_upload
      response.should be_successful
      file_entity = assigns[:file_entity]
      file_entity.binding.should == "https://s3.amazonaws.com/f542aab0-66e4-0130-8d40-442c031da886/uploads%2F20130305T1425Z_eaf29caae12b6d4a101297b45c46dc2a%2FDSC_0549-3.jpg"
      file_entity.storage_location_id.should == "/f542aab0-66e4-0130-8d40-442c031da886/uploads%2F20130305T1425Z_eaf29caae12b6d4a101297b45c46dc2a%2FDSC_0549-3.jpg"
      file_entity.file_name.should == "DSC_0549-3.jpg"
      file_entity.file_size.should == "471990"
      file_entity.mime_type.should == "image/jpeg"
      file_entity.pool.should == @pool
    end
    it "should register the entity from rails-style file params" do
      s3_key = "89d8de30-4013-0131-8fee-7cd1c3f26451_20131205T134412CST"
      params_from_s3_upload = {
          :pool_id=>@pool, format: :json,
          file: {
              "file_name"=>"909-Last-Supper-Large.jpg",
              "mime_type"=>"image/jpeg",
              "file_size"=>"183237",
              "bucket"=>@pool.persistent_id,
              "persistent_id"=>"89d8de30-4013-0131-8fee-7cd1c3f26451",
              "storage_location_id"=>"89d8de30-4013-0131-8fee-7cd1c3f26451_20131205T134412CST",
          }}
      S3Connection.any_instance.stub(:get).and_return(double(:metadata=>{}))
      #FileEntity.should_receive(:register).with(@pool, {"persistent_id"=>"89d8de30-4013-0131-8fee-7cd1c3f26451", "bucket"=>@pool.persistent_id, "data"=>{"file_name"=>"909-Last-Supper-Large.jpg", "mime_type"=>"image/jpeg", "file_size"=>"183237", "storage_location_id"=>"89d8de30-4013-0131-8fee-7cd1c3f26451_20131205T134412CST"}}) { Node.new(pool:@pool, model:Model.file_entity) }
      post :create, params_from_s3_upload
      response.should be_successful
    end
  end

  describe "s3_upload_info" do
    before do
      sign_in @identity.login_credential
      allow(controller).to receive(:prepare_pool_file_store_for_upload)
    end
    it "should generate a pid, storage_location_id, and necessary s3 upload info" do
      get :s3_upload_info, :pool_id=>@pool, :identity_id=>@identity.short_name, format: :json
      json = JSON.parse(response.body)
      response.should be_successful
      placeholder = assigns[:file_entity]
      placeholder.persistent_id.should_not be_nil
      placeholder.storage_location_id.should_not be_nil
      json["policy"].should_not be_nil
      json["signature"].should_not be_nil
      json["key"].should == placeholder.storage_location_id
      json["success_action_redirect"].should == api_v1_pool_file_entities_path(@pool)
      json["uuid"].should == placeholder.persistent_id
    end
  end

  describe "show" do

    subject do
      file_entity = FactoryGirl.create(:node, model: Model.file_entity, pool: @pool)
      file_entity.extend FileEntity
      file_entity.file_entity_type = "S3"
      file_entity.save!
      file_entity
    end
    describe "when not logged in" do
      it "should require authentication" do
        get :show, :pool_id=>@pool, id: subject.persistent_id
        expect(response).to respond_unauthorized
      end
    end
    describe "when logged in as someone who does not have read access to the file entity" do
      it "should not allow access" do
        sign_in identity2.login_credential
        get :show, :pool_id=>@pool, id: subject.persistent_id
        expect(response).to respond_forbidden
      end
    end
    describe "when logged in with read access to the file entity" do
      before do
        sign_in @identity.login_credential
      end
      it "should redirect to s3 authenticated URL" do
        # TODO: Rewrite this so that it doesn't hit s3 every time you run the test.  Tried stubbing s3_url but it wasn't working. - MZ Oct 2013
        get :show, :pool_id=>@pool, :identity_id=>@identity.short_name, id: subject.persistent_id
        expect(response).to redirect_to(subject.s3_url.to_s)
      end
    end
  end

end
