module Bindery::Persistence::ElasticSearch::Node
  extend ActiveSupport::Concern

  included do
    # Schedule a job to create the elasticsearch type
    # Only trigger on create because "updates"
    after_create { NodeIndexer.perform_async(self.id) }
    # Schedule a job to destroy associated elasticsearch artifacts
    after_destroy { NodeDestroyer.perform_async(persistent_id, pool_id, model_id) }
  end

  module ClassMethods

    # Index-agnostic method for generating the appropriate field name to use in index documents.
    # This is used by the Solr implementation to handle solr field name suffixes, etc.
    # The elasticsearch version uses the Field code or, if a string is provided, returns the string as-is.
    # @param field [Field or String] Either the field or its field_name
    # @param args [Hash] These are ignored by the elasticsearch implementation of this method
    def field_name_for_index(field, args = {})
      field_name_for_elasticsearch(field,args)
    end

    def field_name_for_elasticsearch(field,args={})
      if field.kind_of? Field
        field_name = field.code
      else
        field_name = field
      end
      prefix= args[:prefix] || ''
      normalized_field_name = field_name.downcase.gsub(/\s+/,'_')
      return prefix + normalized_field_name
    end

  end

  # Returns the appropriate elasticsearch adapter for this Class
  def __elasticsearch__
    @adapter ||= Adapter.new(self)
  end

  def update_index
    NodeIndexer.perform_async(self.id)
  end

  # Index-agnostic method for rendering the node as a document to be indexed.
  def as_index_document
    as_elasticsearch
  end
  # Index-agnostic method for rendering the node's data and attributes as a document for the index.
  def attributes_for_index
    data_as_elasticsearch
  end
  # Index-agnostic method for rendering the node's associations as a document for the index.
  def associations_for_index
    associations_as_elasticsearch
  end

  def as_elasticsearch
    bindery_data = {'id'=>persistent_id, '_bindery_title'=>title, '_bindery_node_version'=>id, '_bindery_model_name' =>model.name, '_bindery_pool' => pool_id, '_bindery_format'=>'Node', '_bindery_model'=>model_id}
    return data_as_elasticsearch.merge(associations_as_elasticsearch).merge(bindery_data)
  end

  def data_as_elasticsearch
    data
  end

  # Add all the associated models (denormalize) onto this record
  # For example, if this object is a book, you will be able to search by the associated author's name
  def associations_as_elasticsearch
    doc = {}
    # update_file_ids
    model.association_fields.each do |f|
      instances = find_association(f.to_param)
      next unless instances
      doc["_bindery__associations"] ||= []
      instances.each do |instance|
        doc["_bindery__associations"] << instance.persistent_id
        doc[f.to_param] ||= []
        doc[f.to_param] << instance.title
        instance.data.each_pair do |k, v|
          denormalized_field_name = "#{f.to_param}__#{k}"
          doc[denormalized_field_name] ||= []
          doc[denormalized_field_name] << v
        end
      end
    end
    doc
  end

  # Provides adapter which implements the methods to call elasticsearch
  class Adapter
    include Bindery::Persistence::ElasticSearch::Common

    attr_accessor :node
    def initialize(node)
      @node = node
    end

    # Gets the elasticsearch document
    # Accepts all of the optional parameters for Elasticsearch::API::Actions.get
    def get(options={})
      args = options.merge(index:node.pool_id, type:node.model_id, id:node.persistent_id)
      client.get args
    end

    # Creates/Updates an elasticsearch document for this node
    def save
      Bindery::Persistence::ElasticSearch.client.index(id: node.persistent_id, index: node.pool_id, type:node.model_id, body:node.as_elasticsearch )
    end

    # Destroys the elasticsearch document
    def destroy
      Bindery::Persistence::ElasticSearch.client.delete(id: node.persistent_id, index: node.pool_id, type:node.model_id )
    end

  end


  class NodeIndexer
    include Sidekiq::Worker

    # Indexes a single node
    def perform(node_version_id)
      node = Node.find(node_version_id)
      node.__elasticsearch__.save
    end
  end

  class NodeDestroyer
    include Sidekiq::Worker

    # Deletes a single node
    # Because the actual node has usually been deleted before this is run,
    # you must provide the pool_id and model_id (which are used to find the corresponding index and type in elasticsearch)
    def perform(node_persistent_id, pool_id, model_id)
      node = Node.new(persistent_id:node_persistent_id, pool_id:pool_id, model_id:model_id)
      node.__elasticsearch__.destroy
    end
  end
end