module Bindery::Node::Importing
  extend ActiveSupport::Concern

  module ClassMethods
    def bulk_import_data(records, pool, model, key:nil)
      nodes = records.map do |record|
        node = Node.new(pool:pool, model:model, data:record)
        if key && record[key]
          hits = Node.query_elasticsearch(pool:pool, model:model, query:{key => record[key]}, fields:['id'])
          if hits.empty? || hits.first["id"].nil?
            node.generate_uuid
          else
            node.persistent_id = hits.first["id"]
          end
        else
          node.generate_uuid
        end
        node
      end
      self.import_nodes(nodes)
    end

    # Imports the nodes into DataBindery, storing them correctly in the database and in the index (elasticsearch)
    # This Implementation assumes that the base class supports .import For example, via the activerecord-import gem
    def import_nodes(nodes)
      result = self.import(nodes)
      # node_ids = [] # could accumulate the ids and return the array, but this might cause problems when importing thousands of records.   For now, not doing it.
      nodes.each do |n|
        node_id = n.latest_version_id
        # Must query the database to get the id of the imported node so that can be passed to the NodeIndexer job
        # AND so the resulting document in elasticsearch will have the _bindery_node_id value populated.
        # This adds the cost of a database query but allows us to run the elasticsearch import asynchronously...
        Bindery::Persistence::ElasticSearch::Node::NodeIndexer.perform_async(node_id)
      end
      result
    end
  end
end