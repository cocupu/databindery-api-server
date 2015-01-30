require 'rails_helper'

describe Api::V1::NodesController do
  let(:identity) { FactoryGirl.create :identity }
  let(:pool) { FactoryGirl.create :pool, owner:identity }
  let(:not_my_pool) { FactoryGirl.create :pool }

  let(:first_name_field) {Field.create(name:'first_name', 'multivalue' => false)}
  let(:last_name_field) {Field.create(name:'last_name')}
  let(:title_field) {Field.create(name:'title', multivalue:true)}
  # let(:author_association) {OrderedListAssociation.create(name:'title', multivalue:true)}

  let(:model) { FactoryGirl.create(:model, pool:pool, label_field:first_name_field,
                                   fields: [first_name_field, last_name_field, title_field]) }
  let(:not_my_model) { FactoryGirl.create(:model) }

  describe "index" do
    before do
      @node1 = FactoryGirl.create(:node, model:model, pool:pool, data:{first_name_field.to_param=>"Janice", 'undefined'=>'123721'})
      @node2 = FactoryGirl.create(:node, model:model, pool:pool)
      @different_pool_node = FactoryGirl.create(:node, model:model )
      @different_model_node = FactoryGirl.create(:node, pool:pool )
      sign_in identity.login_credential
    end
    it "should load the model and its nodes" do
      get :index, :model_id => model, pool_id: pool
      expect(response).to be_success
      assigns[:model].should == model
      assigns[:nodes].should include(@node1, @node2) 
      assigns[:nodes].should_not include(@different_pool_node) 
      assigns[:nodes].should_not include(@different_model_node) 
    end
    it "should load all the nodes" do
      get :index, pool_id: pool, identity_id: identity
      expect(response).to be_success
      assigns[:nodes].should include(@node1, @node2, @different_model_node) 
      assigns[:nodes].should_not include(@different_pool_node) 
    end
    it "should respond with json" do
      get :index, :format=>'json', pool_id: pool, identity_id: identity
      expect(response).to be_success
      json = JSON.parse(response.body)
      json.map { |n| n["id"]}.should == [ @different_model_node.persistent_id, @node2.persistent_id, @node1.persistent_id]
      json.last.keys.should include("data", "id", "persistent_id", "model_id")
      expect(json.last.to_json).to eq(@node1.to_json)
    end
  end

  describe "search" do
    before do
      @node1 = FactoryGirl.create(:node, model: model, pool: pool, :data=>{first_name_field.to_param =>'Justin', last_name_field.to_param=>'Coyne', title_field.to_param=>'Mr.'})
      @node2 = FactoryGirl.create(:node, model: model, pool: pool, :data=>{first_name_field.to_param=>'Matt', last_name_field.to_param=>'Zumwalt', title_field.to_param=>'Mr.'})
      @different_pool_node = FactoryGirl.create(:node, model: model )
      @different_model_node = FactoryGirl.create(:node, pool: pool)
      sign_in identity.login_credential
    end
    describe "when model is not provided" do
      it "should query everything" do
        get :search, :format=>'json', :pool_id => pool, identity_id: identity.short_name
        expect(response).to be_success
        json = JSON.parse(response.body)
        json.map { |n| n["id"]}.should == [@node1.persistent_id, @node2.persistent_id, @different_model_node.persistent_id]
        expect(json.first).to eq(expected_json_for_node(@node1, :as_json))
      end
    end
    describe "when query is  provided" do
      it "should find nodes that match the query" do
        get :search, :format=>'json', :q=>'Coyne', :pool_id => pool, identity_id: identity.short_name
        expect(response).to be_success
        json = JSON.parse(response.body)
        json.map { |n| n["id"]}.should == [@node1.persistent_id]
        expect(json.first).to eq(expected_json_for_node(@node1, :as_json))
      end
    end
    describe "when model is provided" do
      it "should only find nodes with that model" do
        get :search, :format=>'json', :model_id=>model.id, :pool_id => pool, identity_id: identity.short_name
        expect(response).to be_success
        json = JSON.parse(response.body)
        json.map { |n| n["id"]}.should == [@node1.persistent_id, @node2.persistent_id]
        json.first["data"].should == @node1.data
      end
    end
  end


  describe "show" do
    before do
      @node1 = FactoryGirl.create(:node, model:model, pool:pool)
      @node2 = FactoryGirl.create(:node, model:model, pool:pool)
      @different_pool_node = FactoryGirl.create(:node, model:model )
      @different_model_node = FactoryGirl.create(:node, pool:pool )
      sign_in identity.login_credential
    end
    it "should load the node and the models" do
      pending "Adjust this test for mp3 and ogg"
      get :show, :id => @node1.persistent_id, pool_id:pool, identity_id:identity
      expect(response).to be_success
      assigns[:models].should == [model] # for sidebar
      assigns[:node].should == @node1 
    end
    it "should respond with json" do
      get :show, :id => @node1.persistent_id, :format=>'json', pool_id:pool, identity_id:identity
      expect(response).to be_success
      expect(response.body).to eq( expected_json_for_node(@node1) )
    end
    it "should not load node we don't have access to" do
      get :show, :id => @different_pool_node.persistent_id, pool_id:pool, identity_id:identity
      expect(response).to respond_forbidden
    end
  end
  
  describe "find_or_create" do
    before do
      @node1 = FactoryGirl.create(:node, model: model, pool: pool, :data=>{first_name_field.to_param=>'Justin', last_name_field.to_param=>'Coyne', title_field.to_param=>'Mr.'})
      @node2 = FactoryGirl.create(:node, model: model, pool: pool, :data=>{first_name_field.to_param=>'Matt', last_name_field.to_param=>'Zumwalt', title_field.to_param=>'Mr.'})
      @node3 = FactoryGirl.create(:node, model: model, pool: pool, :data=>{first_name_field.to_param=>'Justin', last_name_field.to_param=>'Ball', title_field.to_param=>'Mr.'})
      sign_in identity.login_credential
    end
    it "should not be successful using a pool I can't edit" do       
      post :find_or_create, :node => {:model_id=>model, :data=>{first_name_field.to_param =>"Justin", last_name_field.to_param => "Coyne"}}, pool_id: not_my_pool, identity_id: identity.short_name
      expect(response).to respond_forbidden
      expect(assigns[:node]).to be_nil
    end
    it "should return existing node node if one already fits the fields & values specified" do
      previous_number_of_nodes = Node.count
      post :find_or_create, :node => {:model_id=>model, :data=>{first_name_field.to_param =>"Justin", last_name_field.to_param => "Coyne"}}, pool_id: pool, identity_id: identity.short_name
      Node.count.should == previous_number_of_nodes
      assigns[:node].data.should == @node1.data
      assigns[:node].model.should == model
    end
    it "should create a new node if none fits the fields & values specified" do
      previous_number_of_nodes = Node.count
      post :find_or_create, :node => {:model_id=>model, :data=>{first_name_field.to_param =>"Randy", last_name_field.to_param => "Reckless"}}, pool_id: pool, identity_id: identity.short_name
      Node.count.should == previous_number_of_nodes + 1
      assigns[:node].data.should == {first_name_field.to_param=>"Randy", last_name_field.to_param=>"Reckless"}
      assigns[:node].model.should == model
    end
    it "should return json" do 
      post :find_or_create, :node => {:model_id=>model, :data=>{first_name_field.to_param =>"Justin", last_name_field.to_param=>"Ball", title_field.to_param=>"Mr."}}, pool_id: pool, identity_id: identity, :format=>:json
      expect(response).to be_success
      # JSON.parse(response.body).keys.should include('persistent_id', 'model_id', 'url', 'pool', 'identity', 'associations', 'binding')
      model.nodes.first.data.should == {first_name_field.to_param=>"Justin", last_name_field.to_param=>"Ball", title_field.to_param=>"Mr."}
      expect( response.body ).to eq( expected_json_for_node(model.nodes.first) )
    end
  end

  describe "create" do
    before do
      sign_in identity.login_credential
    end
    it "should be successful using a model I own" do 
      post :create, :node=>{:binding => '0B4oXai2d4yz6bUstRldTeXV0dHM', :model_id=>model}, pool_id: pool, identity_id: identity.short_name
      expect(response).to be_success
      assigns[:node].binding.should == '0B4oXai2d4yz6bUstRldTeXV0dHM'
      assigns[:node].model.should == model
    end
    it "should not be successful using a model I don't own" do 
      post :create, :node=>{:binding => '0B4oXai2d4yz6bUstRldTeXV0dHM', :model_id=>not_my_model}, pool_id: pool, identity_id: identity.short_name
      expect(response).to respond_bad_request
      expect(assigns[:node].model).to be_nil
    end
    it "should set modified_by on the node it creates" do
      post :create, :node=>{:binding => '0B4oXai2d4yz6bUstRldTeXV0dHM', :model_id=>model}, pool_id: pool, identity_id: identity.short_name
      assigns[:node].modified_by.should == identity
    end
    it "should return json" do 
      post :create, :node=>{:data=> {first_name_field.to_param => 'New val'},  :model_id=>model}, pool_id: pool, identity_id: identity, :format=>:json
      expect(response).to be_success
      model.nodes.count.should == 1
      model.nodes.first.data.should == {first_name_field.to_param => 'New val'}
      expect( response.body ).to eq( expected_json_for_node(model.nodes.first) )
    end
  end

  describe "update" do
    before do
      @node1 = FactoryGirl.create(:node, model: model, pool:pool)
      @node2 = FactoryGirl.create(:node, model: model, pool:pool)
      @different_pool_node = FactoryGirl.create(:node, model: model )
      @different_model_node = FactoryGirl.create(:node, pool:pool )
      sign_in identity.login_credential
    end
    it "should load the node and the models" do
      put :update, :id => @node1.persistent_id, :node=>{data:{ first_name_field.to_param => 'Updated val' }}, pool_id: pool, identity_id: identity
      expect(response).to be_success
      new_version = Node.latest_version(@node1.persistent_id)
      new_version.data[first_name_field.to_param].should == "Updated val"
    end
    it "should not load node we don't have access to" do
      put :update, :id => @different_pool_node.persistent_id, :node=>{:data=>{ }}, pool_id: pool, identity_id: identity
      expect(response).to respond_forbidden
    end
    it "should set modified_by on the node version it creates" do
      put :update, :id => @node1.persistent_id, :node=>{:data=>{ first_name_field.to_param => 'Updated val' }}, pool_id: pool, identity_id: identity
      assigns[:node].modified_by.should == identity
    end
    it "should accept json without fields wrapped in a :node hash" do
      put :update, :id => @node1.persistent_id, :format=>'json', pool_id: pool, identity_id: identity, :data=>{ first_name_field.to_param => 'Updated val' }
      new_version = Node.latest_version(@node1.persistent_id)
      expect(new_version.data[first_name_field.to_param]).to eq "Updated val"
      expect( response.body ).to eq( expected_json_for_node(new_version) )
    end
    it "should return the updated node as json" do
      put :update, :id => @node1.persistent_id, :node=>{:data=>{ first_name_field.to_param => 'Updated val' }}, :format=>'json', pool_id: pool, identity_id: identity
      new_version = Node.latest_version(@node1.persistent_id)
      expect(new_version.data[first_name_field.to_param]).to eq "Updated val"
      expect( response.body ).to eq( expected_json_for_node(new_version) )
    end
    
  end

  describe "import" do
    before do
      sign_in identity.login_credential
    end
    it "should import nodes from an array of data records" do
      r1 = { first_name_field.to_param => 'A val' }
      r2 = { first_name_field.to_param => 'Another val' }
      nodes_before = Node.count
      post :import, :data=>[r1, r2], :model_id=>model, pool_id: pool, identity_id: identity.short_name
      expect(Node.count).to eq(nodes_before + 2)
      expect(Node.last.data).to eq(r1)
      expect(Node.find(Node.last.id+1).data).to eq(r2)
    end
  end

  describe "attach_file" do
    before do
      config = YAML.load_file(Rails.root + 'config/s3.yml')[Rails.env]
      @s3 = FactoryGirl.create(:s3_connection, config.merge(pool: pool))
      @node = FactoryGirl.create(:node, model:model, pool:pool)
      sign_in identity.login_credential
    end
    it "should route" do
      api_v1_pool_node_files_path('my_pool', 567).should == "/api/v1/pools/my_pool/nodes/567/files"
    end
    it "should upload files" do
      uploaded_file = fixture_file_upload('/images/rails.png', 'image/png', true)
      dummy_file_node = FactoryGirl.create(:node, model:model, pool:pool)
      expect(@node).to receive(:attach_file).with("rails.png",uploaded_file).and_return(dummy_file_node)
      expect(Node).to receive(:find_by_persistent_id).with(@node.persistent_id).and_return(@node)
      post :attach_file, pool_id: pool, identity_id: identity,
        node_id: @node.persistent_id, file_name: "rails.png",
        file: uploaded_file
      node = Node.latest_version(@node.persistent_id)
      expect(response).to be_success
      expect(response.body).to eq(expected_json_for_node(dummy_file_node))
    end
  end
  
  describe "delete" do
    before do
      @node1 = FactoryGirl.create(:node, model: model, pool: pool)
      @node2 = FactoryGirl.create(:node, model: model, pool: pool)
      @different_pool_node = FactoryGirl.create(:node, model: model )
      @different_model_node = FactoryGirl.create(:node, pool: pool )
    end
    describe "when not logged on" do
      subject { delete }
      it "should respond unauthorized" do
        delete :destroy, :id=>@node1, pool_id: pool, identity_id: identity
        expect(response).to respond_unauthorized
      end
    end

    describe "when logged on" do
      before do
        sign_in identity.login_credential
      end
      it "should deny action on a node that's not in a pool I have access to" do
        delete :destroy, :id=>@different_pool_node, pool_id: pool, identity_id: identity
        expect(response).to respond_forbidden
      end
      
      it "should be able to delete a node" do
        node_id = @node1.id
        node_label = @node1.title
        delete :destroy, :id=>@node1, pool_id: pool, identity_id: identity
        expect(response).to respond_deleted(description:"Deleted node #{node_id} (#{node_label}) from Pool #{pool.id}.")
        lambda{Node.find(node_id)}.should raise_exception ActiveRecord::RecordNotFound
      end
    end
  end

  def expected_json_for_node(n, format_method=:to_json)
    serialized_node = controller.send(:serialize_node, n)
    if serialized_node["parent_id"]
      serialized_node["parent_id"] = serialized_node["parent_id"].to_i # Fixes quirk of inconstency in how this field is converted to json
    end
    serialized_node.send(format_method)
  end

end
