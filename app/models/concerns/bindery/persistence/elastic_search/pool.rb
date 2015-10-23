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

  delegate :search, to:'__elasticsearch__'

  # Index-agnostic method name for applying query params based on an identity
  def apply_query_params_for_identity(identity, query_builder=Bindery::Persistence::ElasticSearch::Query::QueryBuilder.new, user_params={})
    apply_elasticsearch_params_for_identity(identity, query_builder, user_params)
  end

  # Applies elasticsearch query params based on an identity
  def apply_elasticsearch_params_for_identity(identity, query_builder=Bindery::Persistence::ElasticSearch::Query::QueryBuilder.new, user_params={})
    unless query_builder.instance_of?(Bindery::Persistence::ElasticSearch::Query::QueryBuilder)
      raise ArgumentError, "query_builder must be an instance of Bindery::Persistence::ElasticSearch::Query::QueryBuilder"
    end
    # Unless user has explicit read/edit access, apply filters based on audience memberships
    if access_controls.where(identity_id:identity.id).empty?
      filters = []
      audiences_for_identity(identity).each do |audience|
        filters.concat(audience.filters)
      end
      if filters.empty?
        # This means the indentity has not been granted any access to any content.  Prevent any documents from being returned.
        query_builder.filters.must.add_filter(:ids, {values:["NONEXISTENT_ID"]})
      else
        SearchFilter.apply_elasticsearch_params_for_filters(filters, query_builder, user_params)
      end
    end
    return query_builder, user_params
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
      index_name = create_index
      set_alias(index_name)
    end

    # Deletes corresponding index and aliases from elasticsearch
    def destroy_artifacts
      # Providing the alias name as the value of :index tells elasticsearch to delete the alias and the index it points to.
      begin
        client.indices.delete index: pool.to_param
      rescue Elasticsearch::Transport::Transport::Errors::NotFound => e
        # Index doesn't exist, so don't need to delete it.  Do nothing.
      end
    end

    alias :create :create_artifacts
    alias :destroy :destroy_artifacts

    # Creates an elasticsearch index
    # Defaults to naming indices {pool.id}_{Time.now.strftime('%Y-%m-%d_%H:%m:%S')}
    # @example Creating an index for pool 1862
    #   pool.__elasticsearch__.create_index
    #   => "1862_2015-01-29_15:01:39"
    # @example Specify an index_name
    #   pool.__elasticsearch__.create_index(index_name:"foo-index")
    #   => "foo-index"
    # @example Specify a base_name
    #   pool.__elasticsearch__.create_index(base_name:"foo-index")
    #   => "foo-index_2015-01-29_15:01:39"
    # @example Specify a suffix
    #   pool.__elasticsearch__.create_index(suffix:"my-suffix")
    #   => "1862_my-suffix"
    def create_index(suffix: nil, base_name: nil, index_name: nil)
      unless index_name
        suffix = "_" + Time.now.strftime('%Y-%m-%d_%H:%m:%S') unless suffix
        base_name =  pool.to_param unless base_name
        index_name = base_name + suffix
      end
      client.indices.create index: index_name
      return index_name
    end

    # The names of all the indices belonging to this pool, plus the name of the default/live alias
    def index_names(scope: :all)
      get_aliases(scope: scope).keys + [pool.to_param]
    end

    # Returns the name of the index that the live alias currently points to
    def current_live_index
      get_aliases(scope: :live).keys.first
    end

    def delete_index(index_name)
      client.indices.delete index: index_name
    end

    def delete_all_indices
      get_aliases(scope: :all).keys do |index_name|
        delete_index(index_name)
      end
    end

    # Sets this pool's elasticsearch alias to point to the index named :index_name
    def set_alias(index_name)
      old_aliases = get_aliases
      client.indices.put_alias name: pool.to_param, index: index_name
      client.indices.put_alias name: pool.to_param + "-all" , index: index_name
      old_aliases.keys.each {|index_name| remove_alias(index_name)}
    end

    def get_aliases(scope: :live)
      found_aliases = {}
      begin
        case scope
          when :live
            found_aliases = client.indices.get_alias name: pool.to_param
          when '_all', :all
            found_aliases = client.indices.get_alias name: pool.to_param
            found_aliases.merge!(client.indices.get_alias name: pool.to_param + '-all')
        end
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        found_aliases
      end
      found_aliases
    end

    def remove_alias(index_name, scope: :live)
      case scope
        when :live
          client.indices.delete_alias name: pool.to_param, index: index_name
        when '_all', :all
          client.indices.delete_alias name: pool.to_param, index: index_name
          client.indices.delete_alias name: pool.to_param, index: index_name + '_all'
      end
    end

    def get
      client.indices.get index: index_name
    end

    # Ensures that the query is directed at this pool's index
    def query_builder(query_params={})
      case query_params
        when Bindery::Persistence::ElasticSearch::Query::QueryBuilder
          query_builder = query_params
        when Hash
          query_builder_params = {index:pool.to_param}
          [:type, :body, :fields].each do |key|
            if query_params.has_key?(key)
              query_builder_params[key] = query_params[key]
            end
          end
          query_builder =  Bindery::Persistence::ElasticSearch::Query::QueryBuilder.new(query_builder_params)
        else
          raise ArgumentError, "This method only accepts a QueryBuilder or a Hash"
      end
      query_builder.index = pool.to_param
      return query_builder
    end

    # Ensures that the query is directed at this pool's index
    def search(query_params)
      Rails.logger.debug "[elasticsearch query] #{query_builder(query_params).as_query}"
      response = client.search query_builder(query_params).as_query
      return response, response["hits"]["hits"]
    end

  end

end