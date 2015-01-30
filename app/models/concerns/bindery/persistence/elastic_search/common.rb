# Common methods used by many/all of the Bindery::Persistence::ElasticSearch modules
module Bindery::Persistence::ElasticSearch::Common

  extend ActiveSupport::Concern

  included do
    def client
      @client ||= Bindery::Persistence::ElasticSearch.client
    end
  end

  # Get the elasticsearch client connection
  def client
    self.class.client
  end

end
