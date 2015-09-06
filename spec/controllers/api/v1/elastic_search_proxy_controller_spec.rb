require 'rails_helper'

describe Api::V1::ElasticSearchProxyController do

  let(:identity) { FactoryGirl.create :identity }
  let(:other_identity) { FactoryGirl.create :identity }
  let(:my_pool) { FactoryGirl.create :pool, owner:identity }
  let(:other_pool) { FactoryGirl.create :pool, owner:identity }
  let(:not_my_pool) { FactoryGirl.create :pool, owner:FactoryGirl.create(:identity) }
  let(:business_opportunity_email_query) do
    {"query" => {
        "filtered"=> {
            "query"=>  { "match"=> { "email"=> "business opportunity" }},
            "filter"=> { "term"=>  { "folder"=> "inbox" }}
        }
    }}
  end

  context "with read access" do
    before do
      sign_in identity.login_credential
    end
    describe "get" do
      before do
        get :index, id: my_pool, body: business_opportunity_email_query
      end
      it "runs query against the pool's index based on submitted parameters" do
        expect(controller.query_builder.index).to eq(my_pool.to_param)
        expect(controller.query_builder.body).to eq(business_opportunity_email_query)
        # expect(my_pool.__elasticsearch__.client).to have_received(:search).with({index:my_pool.to_param, body: business_opportunity_email_query)
      end
    end
    describe "post" do
      before do
        post :index, id: my_pool, body: business_opportunity_email_query
      end
      it "runs query against the pool's index based on posted parameters" do
        expect(controller.query_builder.index).to eq(my_pool.to_param)
        expect(controller.query_builder.body).to eq(business_opportunity_email_query)
        # expect(my_pool.__elasticsearch__.client).to have_received(:search).with({index:my_pool.to_param, body:{}})
      end
    end
  end

  context "without read access" do
    before do
      sign_in other_identity.login_credential
    end
    describe "get" do
      it "denies access" do
        get :index, id: my_pool
        expect(response).to respond_forbidden
      end
    end
    describe "post" do
      it "denies access" do
        post :index, id: my_pool
        expect(response).to respond_forbidden
      end
    end
  end

  context "when not logged in" do
    describe "get" do
      it "denies access" do
        get :index, id: my_pool
        expect(response).to respond_unauthorized
      end
    end
    describe "post" do
      it "denies access" do
        post :index, id: my_pool
        expect(response).to respond_unauthorized
      end
    end
  end

  it "does not respond to show, edit, create or destroy"
end