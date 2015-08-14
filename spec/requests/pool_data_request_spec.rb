require 'rails_helper'

describe 'Pool Data Requests' do
  let(:identity)          { FactoryGirl.create :identity }
  let(:login_credential)  { identity.login_credential }
  let(:pool)              { FactoryGirl.create :pool, owner: identity }

  before do
    env=Hash.new
    env["CONTENT_TYPE"] = "application/json"
    env["ACCEPT"] = "application/json"
    env["HTTP_AUTHORIZATION"] = "Basic " + Base64::encode64("#{login_credential.email}:#{login_credential.password}")
    env["Origin"] = "http://localhost:3000"
    get "/api/v1/pools/#{pool.id}/data", {}, env
  end

  # it_should_behave_like "any request"
  it_behaves_like "any request"

  it "supports basic auth" do
    pending "see https://github.com/lynndylanhurley/devise_token_auth/issues/337"
    expect(response).to be_successful
    expect(response.body).to include("hits")
  end

end