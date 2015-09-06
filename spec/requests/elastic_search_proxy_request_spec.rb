require 'rails_helper'

describe 'ElasticSearch Proxy Requests' do
  let(:identity)          { FactoryGirl.create :identity }
  let(:login_credential)  { identity.login_credential }
  let(:pool)              { FactoryGirl.create :pool, owner: identity }
  let(:env)               { Hash.new }
  subject { response }

  context "with read access" do
    before do
      env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(login_credential.email, login_credential.password)
    end
    describe "get" do
      before do
        get "/api/v1/pools/#{pool.id}/_search", {}, env
      end
      it "returns search results" do
        expect(response.body).to eq('{"hits":{"hits":[]}}')
      end
    end
    describe "post" do
      before do
        post "/api/v1/pools/#{pool.id}/_search", {}, env
      end
      it "returns search results" do
        expect(response.body).to eq('{"hits":{"hits":[]}}')
      end
    end
  end

  context 'without read access' do
    let(:login_credential)          { FactoryGirl.create :login_credential, email: 'randomdude@dudebro.com' }
    before do
      env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(login_credential.email, login_credential.password)
    end
    describe "get" do
      before do
        get "/api/v1/pools/#{pool.id}/_search", {}, env
      end
      it { is_expected.to respond_forbidden }
    end
    describe "post" do
      before do
        post "/api/v1/pools/#{pool.id}/_search", {}, env
      end
      it { is_expected.to respond_forbidden }
    end
  end
end
