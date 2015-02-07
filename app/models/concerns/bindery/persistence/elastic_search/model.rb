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

    # Create/Update the elasticsearch type for this Model
    def save
      Bindery::Persistence::ElasticSearch.client.indices.put_mapping index: model.pool.to_param, type: model.to_param, body: model.to_elasticsearch
    end

    # Destroy all elasticsearch artifacts associated with this Model
    def destroy
      Bindery::Persistence::ElasticSearch.client.indices.delete_mapping index: model.pool.to_param, type: model.to_param
    end

    def get
      Bindery::Persistence::ElasticSearch.client.indices.get_mapping(index: model.pool.to_param, type: model.id).values.first["mappings"][model.to_param]
    end

  end


end