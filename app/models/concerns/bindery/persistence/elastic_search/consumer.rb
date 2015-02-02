# Generic behaviors for Classes that consume data from Elasticsearch (via search APIs)
module Bindery::Persistence::ElasticSearch::Consumer
  extend ActiveSupport::Concern

  included do
  end

  # Returns the appropriate elasticsearch adapter for this Class
  def __elasticsearch__
    @adapter ||= SearchAdapter.new(self)
  end

  # Provides adapter which implements the methods to call elasticsearch
  class SearchAdapter
    include Bindery::Persistence::ElasticSearch::Common

    def search
      client.indexes.search()
      return response, response["hits"]["hits"]
    end
  end

end
