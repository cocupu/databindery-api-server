module Bindery::Persistence::ElasticSearch::Node
  extend ActiveSupport::Concern

  included do
    # Schedule a job to create the elasticsearch type
    after_save { NodeIndexer.perform_async(self.persistent_id, index: self.pool.to_param, type:self.model.to_param, body:self.to_elasticsearch) }
    # Schedule a job to destroy associated elasticsearch artifacts
    after_destroy { NodeDestroyer.perform_async(self.pool.to_param, self.to_param) }
  end

  def to_elasticsearch
    bindery_data = {'id'=>persistent_id, '_bindery_title'=>title, '_bindery_node_version'=>id, '_bindery_model_name' =>model.name, '_bindery_pool' => pool_id, '_bindery_format'=>'Node', '_bindery_model'=>model_id}
    return data.merge(associations_as_elasticsearch).merge(bindery_data)
  end

  # Solrize all the associated models (denormalize) onto this record
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
      if options.has_key?(:index) && options.has_key?(:type) && options.has_key?(:body)
        args = options.merge(id:node_persistent_id)
      else
        node = ::Node.latest_version(node_persistent_id)
        args = {id: node_persistent_id, index: node.pool_id, type:node.model_id, body:node.to_elasticsearch }
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
      if options.has_key?(:index) && options.has_key?(:type)
        args = options.merge(id:node_persistent_id)
      else
        node = ::Node.latest_version(node_persistent_id)
        args = {id: node_persistent_id, index: node.pool_id, type:node.model_id }
      end
      Bindery::Persistence::ElasticSearch.client.delete index: 'myindex', type: 'mytype', id: '1'
    end
  end
end