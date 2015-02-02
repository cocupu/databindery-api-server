module Bindery::Persistence::ElasticSearch::Node
  extend ActiveSupport::Concern

  included do
    # Schedule a job to create the elasticsearch type
    # Only trigger on create because "updates"
    after_create { NodeIndexer.perform_async(self.persistent_id, index: self.pool.to_param, type:self.model.to_param, body:self.as_elasticsearch) }
    # Schedule a job to destroy associated elasticsearch artifacts
    after_destroy { NodeDestroyer.perform_async(self.persistent_id, index: self.pool.to_param, type:self.model.to_param) }
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

  class NodeIndexer
    include Sidekiq::Worker

    # Indexes a single node
    # If index, type, and document body are all provided in the options {index: 'myindex', type: 'mytype', body: {...}} they will be used
    # If all of these are not provided, the node will be loaded from the database and values will be generated from the loaded node.
    def perform(node_persistent_id, options={})
      if options.has_key?("index") && options.has_key?("type") && options.has_key?("body")
        args = {id: node_persistent_id, index: options["index"], type:options["type"], body:options['body'] }
      else
        node = ::Node.latest_version(node_persistent_id)
        args = {id: node_persistent_id, index: node.pool_id, type:node.model_id, body:node.as_elasticsearch }
      end
      Bindery::Persistence::ElasticSearch.client.index(args)
    end
  end

  class NodeDestroyer
    include Sidekiq::Worker

    # Deletes a single node
    # If index and type are both provided in the options {index: 'myindex', type: 'mytype'} they will be used
    # If both of these are not provided, the node will be loaded from the database and values will be generated from the loaded node.
    def perform(node_persistent_id, options={})
      if options.has_key?("index") && options.has_key?("type")
        args = {id: node_persistent_id, index: options["index"], type:options["type"] }
      else
        raise ArgumentError, "Can't remove document from elasticsearch without knowing the index and type. You provided #{options}"
      end
      Bindery::Persistence::ElasticSearch.client.delete args
    end
  end
end