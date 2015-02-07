require 'rails_helper'

describe Api::V1::PoolDataController, sidekiq: :inline, elasticsearch:true do
    
  before(:all) do
    Sidekiq::Testing.inline! # Ensure that node Indexers are run in this before(:all) block
    @identity = FactoryGirl.create :identity
    @pool =  FactoryGirl.create :pool, owner:@identity
    @access_level_field = FactoryGirl.create(:access_level_field)
    @location_field = FactoryGirl.create(:location_field)
    @full_name_field = FactoryGirl.create(:full_name_field)
    @subject_field = FactoryGirl.create(:subject_field)

    @model1 =  FactoryGirl.create(:model, pool:@pool, name:"Things", fields:[@full_name_field, @location_field])
    @model2 =  FactoryGirl.create(:model, pool:@pool, name:"Restricted Things", fields:[@access_level_field, @subject_field])

    @pool.audience_categories.build.save
    @node_kittens = FactoryGirl.create(:node, pool:@pool, model:@model1, data:{@full_name_field.to_param=>"Kittens", @location_field.to_param=>"Albuquerque"})
    @node_puppies = FactoryGirl.create(:node, pool:@pool, model:@model1, data:{@full_name_field.to_param=>"Puppies", @location_field.to_param=>"Albuquerque"})
    @node_pandas = FactoryGirl.create(:node, pool:@pool, model:@model1, data:{@full_name_field.to_param=>"Pandas", @location_field.to_param=>"Yunan"})
    @node_ordinary1 = FactoryGirl.create(:node, pool:@pool, model:@model2, data:{@access_level_field.to_param=>"ordinary", @subject_field.to_param=>"Ordinary 1"})
    @node_ordinary2 = FactoryGirl.create(:node, pool:@pool, model:@model2, data:{@access_level_field.to_param=>"ordinary", @subject_field.to_param=>"Ordinary 2"})
    @node_special = FactoryGirl.create(:node, pool:@pool, model:@model2, data:{@access_level_field.to_param=>"special", @subject_field.to_param=>"Special"})
    @node_extra_special = FactoryGirl.create(:node, pool:@pool, model:@model2, data:{@access_level_field.to_param=>"extra_special", @subject_field.to_param=>"Extra Special"})
    sleep 1
  end

  let(:identity) {@identity}
  let(:pool) {@pool}
  let(:access_level_field) {@access_level_field}
  let(:location_field) {@location_field }
  let(:full_name_field) {@full_name_field}
  let(:subject_field) {@subject_field}

  let(:model1) { @model1 }
  let(:model2) { @model2 }


  before(:each) do
    @identity = FactoryGirl.create :identity
    sign_in @identity.login_credential
  end
  describe "when I am a contributor on the pool (EDIT access)" do
    before do
      AccessControl.create!(:pool=>pool, :identity=>@identity, :access=>'EDIT')
    end
    it "I should see everything" do
      get :index, pool_id: pool, identity_id: identity.short_name
      assigns[:document_list].count.should == 7
    end
    it "I should not be constrained by filters from any audiences I am in" do
      @audience = pool.audience_categories.first.audiences.build(filters_attributes:[{filter_type:"RESTRICT", field:access_level_field, operator:"+", values:["ordinary"]}])
      @audience.members << @identity
      @audience.save
      get :index, pool_id: pool, identity_id: identity.short_name
      assigns[:document_list].count.should == 7
    end
  end
  describe "when I have been granted READ access to the pool" do
    before do
      AccessControl.create!(:pool=>pool, :identity=>@identity, :access=>'READ')
    end
    it "I should see everything" do
      get :index, pool_id: pool, identity_id: identity.short_name
      assigns[:document_list].count.should == 7
    end
    it "I should not be constrained by filters from any audiences I am in" do
      @audience = pool.audience_categories.first.audiences.build(filters_attributes:[{filter_type:"RESTRICT", field:access_level_field, operator:"+", values:["ordinary"]}])
      @audience.members << @identity
      @audience.save
      get :index, pool_id: pool, identity_id: identity.short_name
      assigns[:document_list].count.should == 7
    end
  end
  describe "when I do not belong to any audience for the pool" do
    it "I should forbid action" do
      get :index, pool_id: pool, identity_id: identity.short_name
      expect(response).to respond_forbidden
    end
  end
  describe "when I belong to an audience that has no filters" do
    before do
      @audience = pool.audience_categories.first.audiences.build
      @audience.members << @identity
      @audience.save
    end
    it "I should not see anything" do
      get :index, pool_id: pool, identity_id: identity.short_name
      assigns[:document_list].count.should == 0
    end
    it "I should not see anything even if additional filters are applied" do
      get :index, pool_id: pool, identity_id: identity.short_name, f:{Node.field_name_for_index("full_name", type: "facet") => "Kittens"}
      assigns[:document_list].count.should == 0
    end
  end
  describe "when I belong to one audience that defines one filter" do
    before do
      @audience = pool.audience_categories.first.audiences.build(filters_attributes:[{field:access_level_field, operator:"+", values:["ordinary"]}])
      @audience.members << @identity
      @audience.save
    end
    it "I should see everything that matches the filter" do
      get :index, pool_id: pool, identity_id: identity.short_name
      assigns[:document_list].count.should == 2
    end
  end
  describe "when I belong to an audience that defines multiple filters" do
    before do
      @audience = pool.audience_categories.first.audiences.build(filters_attributes:[{field:access_level_field, operator:"+", values:["ordinary"]},{field:location_field, operator:"+", values:["Albuquerque"]}])
      @audience.members << @identity
      @audience.save
    end
    it "the filters should be cumulative" do
      get :index, pool_id: pool, identity_id: identity.short_name
      assigns[:document_list].count.should == 4
    end
  end
  describe "when I belong to multiple audiences that define multiple filters" do
    before do
      @audience = pool.audience_categories.first.audiences.build(filters_attributes:[{field:access_level_field, operator:"+", values:["ordinary"]}])
      @audience.members << @identity
      @audience.save
      @audience2 = pool.audience_categories.first.audiences.build(filters_attributes:[{field:location_field, operator:"+", values:["Albuquerque"]}])
      @audience2.members << @identity
      @audience2.save
    end
    it "the filters should be cumulative" do
      get :index, pool_id: pool, identity_id: identity.short_name
      assigns[:document_list].count.should == 4
    end
  end
  describe "when I belong to multiple audiences that defines a RESTRICT filter" do
    before do
      @audience = pool.audience_categories.first.audiences.build(filters_attributes:[{filter_type:"RESTRICT", field:access_level_field, operator:"+", values:["ordinary"]}])
      @audience.members << @identity
      @audience.save
    end
    it "I should only see content fitting that restriction" do
      get :index, pool_id: pool, identity_id: identity.short_name
      assigns[:document_list].count.should == 2
    end
  end
end