# Generic behaviors for Classes that consume data from Elasticsearch (via search APIs)
module Bindery::Persistence::ElasticSearch::Consumer
  extend ActiveSupport::Concern

  included do
    # Class Attribute for tracking query_logic callbacks that will be applied
    # to the query_builder
    class_attribute :query_logic

    # query_logic defaults to empty
    # Note: It's important to use +=, not << when appending new query_logic callbacks
    # because it sets a new array rather than appending to the array initialized by
    # Bindery::Persistence::ElasticSearch::Consumer.
    # This pattern for preventing bleed-over also applies to subclasses
    self.query_logic = []
  end

  def get_search_results(extra_params={})
    Bindery::Persistence::ElasticSearch.client.search(query_builder(extra_params))
  end

  def query_builder(extra_params={})
    query_builder = Bindery::Persistence::ElasticSearch::Query::QueryBuilder.new(index:@pool.to_param)
    self.class.query_logic.each do |query_logic_callback|
      self.send(query_logic_callback, query_builder, params.merge(extra_params))
    end
    return query_builder
  end

  private

  def apply_audience_filters(query_builder, user_parameters)
    unless can? :edit, @pool
      @pool.apply_query_params_for_identity(current_identity, query_builder, user_parameters)
    end
  end

  # # Returns the appropriate elasticsearch adapter for this Class
  # def __elasticsearch__
  #   @adapter ||= SearchAdapter.new(self)
  # end
  #
  # # Provides adapter which implements the methods to call elasticsearch
  # class SearchAdapter
  #   include Bindery::Persistence::ElasticSearch::Common
  #
  #   def search
  #     client.indexes.search()
  #     return response, response["hits"]["hits"]
  #   end
  # end

end
