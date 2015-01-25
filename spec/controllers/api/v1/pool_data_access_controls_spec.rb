require 'rails_helper'

describe Api::V1::PoolDataController do
  let(:identity) { FactoryGirl.create :identity }
  let(:pool) { FactoryGirl.create :pool, owner:identity }

  let(:access_level_field) {FactoryGirl.create(:access_level_field)}
  let(:location_field) {FactoryGirl.create(:location_field)}
  let(:full_name_field) {FactoryGirl.create(:full_name_field)}
  let(:subject_field) {FactoryGirl.create(:subject_field)}

  let(:model1) { FactoryGirl.create(:model, pool:pool, name:"Things", fields:[full_name_field, location_field]) }
  let(:model2) { FactoryGirl.create(:model, pool:pool, name:"Restricted Things", fields:[access_level_field, subject_field]) }

    
  before do
    pool.audience_categories.build.save
    @node_kittens = FactoryGirl.create(:node, pool:pool, model:model1, data:{full_name_field.id.to_s=>"Kittens", location_field.id.to_s=>"Albuquerque"})
    @node_puppies = FactoryGirl.create(:node, pool:pool, model:model1, data:{full_name_field.id.to_s=>"Puppies", location_field.id.to_s=>"Albuquerque"})
    @node_pandas = FactoryGirl.create(:node, pool:pool, model:model1, data:{full_name_field.id.to_s=>"Pandas", location_field.id.to_s=>"Yunan"})
    @node_ordinary1 = FactoryGirl.create(:node, pool:pool, model:model2, data:{access_level_field.id.to_s=>"ordinary", subject_field.id.to_s=>"Ordinary 1"})
    @node_ordinary2 = FactoryGirl.create(:node, pool:pool, model:model2, data:{access_level_field.id.to_s=>"ordinary", subject_field.id.to_s=>"Ordinary 2"})
    @node_special = FactoryGirl.create(:node, pool:pool, model:model2, data:{access_level_field.id.to_s=>"special", subject_field.id.to_s=>"Special"})
    @node_extra_special = FactoryGirl.create(:node, pool:pool, model:model2, data:{access_level_field.id.to_s=>"extra_special", subject_field.id.to_s=>"Extra Special"})
  end
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