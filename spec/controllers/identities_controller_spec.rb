require 'rails_helper'

describe IdentitiesController do

  describe "index" do
    before do
      @identity = FactoryGirl.create :identity
      @second_identity = FactoryGirl.create :identity
      allow(controller).to receive(:current_login_credential).and_return @identity.login_credential
    end
    it "should give a json formatted list of identities available for the current user" do
      identity2 = FactoryGirl.create :identity, login_credential: @identity.login_credential
      get :index
      response.should be_success
      assigns[:identities].count.should == 2
      assigns[:identities].should include(@identity)
      assigns[:identities].should include(identity2)
      json = JSON.parse(response.body)
      identity_json = json.select {|i| i["id"] == @identity.id}.first
      identity_json.delete("created_at")
      identity_json.delete("updated_at")
      identity_json.should == {"id"=>@identity.id, "name"=>@identity.name, "short_name"=>@identity.short_name, "url"=>"/api/identities/#{@identity.id}"}
    end
    it "should allow searching for identities belonging to email address" do
      get :index, email:@identity.login_credential.email
      assigns[:identities].should == @identity.login_credential.identities.all
    end
  end

end
