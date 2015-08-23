require 'rails_helper'

describe 'Pool Data Requests' do
  let(:identity)          { FactoryGirl.create :identity }
  let(:login_credential)  { identity.login_credential }
  let(:pool)              { FactoryGirl.create :pool, owner: identity }
  let(:env)               { Hash.new }

  before do
    env["CONTENT_TYPE"] = "application/json"
    env["ACCEPT"] = "application/json"
    env["Origin"] = "http://localhost:3000"
  end

  context "with basic auth header" do
    before do
      env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(login_credential.email, login_credential.password)
      get "/api/v1/pools/#{pool.id}/data", {}, env
    end

    # it_should_behave_like "any request"
    it_behaves_like "any request"

    it "supports basic auth" do
      expect(response).to be_successful
      expect(response.body).to include("hits")
    end
  end

  context "without basic auth header" do
    before do
      get "/api/v1/pools/#{pool.id}/data", {}, env
    end

    # it_should_behave_like "any request"
    it_behaves_like "any request"

    it "does not run basic auth" do
      expect(response).to respond_unauthorized
    end
  end


end