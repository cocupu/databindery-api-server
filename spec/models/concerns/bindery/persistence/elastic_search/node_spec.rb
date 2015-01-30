require  'rails_helper'

describe Bindery::Persistence::ElasticSearch::Pool do

  subject{ FactoryGirl.create(:node) }
  let(:elasticsearch) { Bindery::Persistence::ElasticSearch.client }

  it "uses an asynchronous job to index its data into elasticsearch"

end
