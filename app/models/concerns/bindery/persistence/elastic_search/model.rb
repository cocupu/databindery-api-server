module Bindery::Persistence::ElasticSearch::Model
  extend ActiveSupport::Concern

  include Bindery::Persistence::ElasticSearch::Common

  included do
    after_save { __elasticsearch__.save }
    after_destroy { __elasticsearch__.destroy }
  end

  # Returns the appropriate elasticsearch adapter for this Class
  def __elasticsearch__
    @adapter ||= Adapter.new(self)
  end

  def to_elasticsearch
    {
        self.id => {
            properties: elasticsearch_mapping_fields
        }
    }
  end

  def mapping_from_elasticsearch
    Bindery::Persistence::ElasticSearch.client.indices.get_mapping(index: pool.id, type: self.id).values.first["mappings"][self.to_param]
  end

  def elasticsearch_mapping_fields
    mapping_fields = {}
    fields.each do |field|
      unless field.elasticsearch_attributes.empty?
        mapping_fields[field.code] = field.elasticsearch_attributes
      end
    end
    mapping_fields
  end

  class Adapter

    attr_accessor :model
    def initialize(model)
      @model = model
    end

    # Create/Update the elasticsearch type for this Model in index +index_name+
    # @option [String] index_name defaults to pool's live index
    def save(index_name: nil)
      index_name ||= model.pool.to_param
      Bindery::Persistence::ElasticSearch.client.indices.put_mapping index: index_name, type: model.to_param, body: model.to_elasticsearch
    end

    # Destroy all elasticsearch artifacts associated with this Model from index +index_name+
    # @option [String] index_name defaults to pool's live index
    def destroy(index_name: nil)
      index_name ||= model.pool.to_param
      begin
        Bindery::Persistence::ElasticSearch.client.indices.delete_mapping index: index_name, type: model.to_param
      rescue Elasticsearch::Transport::Transport::Errors::NotFound => e
        # Mapping doesn't exist, so don't need to delete it.  Do nothing.
      end
    end

    # Get the elasticsearch mapping associated with this Model in index +index_name+
    # @option [String] index_name defaults to pool's live index
    def get(index_name: nil)
      index_name ||= model.pool.to_param
      Bindery::Persistence::ElasticSearch.client.indices.get_mapping(index: index_name, type: model.id).values.first["mappings"][model.to_param]
    end

  end


end