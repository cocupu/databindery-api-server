module Bindery::Node::Importing
  extend ActiveSupport::Concern

  module ClassMethods
    def bulk_import_data(records, pool, model)
      nodes = records.map do |record|
        node = Node.new(pool:pool, model:model, data:record)
        node.generate_uuid
        node
      end
      self.import_nodes(nodes)
    end

    # Imports the nodes into DataBindery, storing them correctly in the database and in the index (elasticsearch)
    # This Implementation assumes that the base class supports .import For example, via the activerecord-import gem
    def import_nodes(nodes)
      result = self.import(nodes)
      Bindery::Persistence::ElasticSearch.add_documents_to_index( nodes.map {|n| n.as_index_document} )
      result
    end
  end
end
