# A DataBindery Pool roughly equates to an elasticsearch Index
# Adds the behaviors that allow DataBindery to manage this correlation
#
# Uses aliases to allow for transparent rebuilding of indices.  See # See: http://www.elasticsearch.org/blog/changing-mapping-with-zero-downtime/
module Bindery::Persistence::ElasticSearch::Pool
  extend ActiveSupport::Concern

  included do
    after_create { __elasticsearch__.create_artifacts }
    after_destroy { __elasticsearch__.destroy_artifacts }
  end

  # Returns the appropriate elasticsearch adapter for this Class
  def __elasticsearch__
    @adapter ||= Adapter.new(self)
  end

  # Index-agnostic method name for applying query params based on an identity
  def apply_query_params_for_identity(identity, query_params={}, user_params={})
    apply_elasticsearch_params_for_identity(identity, query_params, user_params)
  end

  # Applies elasticsearch query params based on an identity
  def apply_elasticsearch_params_for_identity(identity, elasticsearch_params={}, user_params={})
    # Unless user has explicit read/edit access, apply filters based on audience memberships
    if access_controls.where(identity_id:identity.id).empty?
      filters = []
      audiences_for_identity(identity).each do |audience|
        filters.concat(audience.filters)
      end
      if filters.empty?
        SearchFilter.apply_elasticsearch_params_for_filters(default_filters, elasticsearch_params, user_params)
      else
        SearchFilter.apply_elasticsearch_params_for_filters(filters, elasticsearch_params, user_params)
      end
    end
    return elasticsearch_params, user_params
  end

  # Provides adapter which implements the methods to call elasticsearch
  class Adapter
    include Bindery::Persistence::ElasticSearch::Common

    attr_accessor :pool
    def initialize(pool)
      @pool = pool
    end

    # Creates elasticsearch index and and alias (pool.to_param) that points to the index
    def create_artifacts
      # Bindery::Persistence::ElasticSearch::Pool.create_elasticsearch_artifacts(self.to_param)
      index_name = create_index(pool.to_param)
      set_alias(index_name)
    end

    # Deletes corresponding index and aliases from elasticsearch
    def destroy_artifacts
      # Providing the alias name as the value of :index tells elasticsearch to delete the alias and the index it points to.
      client.indices.delete index: pool.to_param
    end

    # Creates an elasticsearch index
    # Defaults to naming indices {pool.id}_{Time.now.strftime('%Y-%m-%d_%H:%m:%S')}
    # @example Creating an index for pool 1862
    #   create_elasticsearch_index
    #   => 1862_2015-01-29_15:01:39
    def create_index(pool_identifier, opts={})
      suffix = opts.fetch(:suffix, "_" + Time.now.strftime('%Y-%m-%d_%H:%m:%S'))
      index_name = opts.fetch(:name, pool_identifier + suffix )
      client.indices.create index: index_name
      return index_name
    end

    # Sets this pool's elasticsearch alias to point to the index named :index_name
    def set_alias(index_name)
      client.indices.put_alias name: pool.to_param, index: index_name
    end

  end

end