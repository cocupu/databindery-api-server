module Bindery::Node::Importing
  extend ActiveSupport::Concern

  module ClassMethods
    def bulk_import_records(records, pool, model)
      nodes = records.map do |record|
        node = Node.new(pool:pool, model:model, data:record)
        node.generate_uuid
        node
      end
      self.import_nodes(nodes)
    end

    def import_nodes(nodes)
      result = self.import(nodes)
      Bindery.index( nodes.map {|n| n.to_solr} )
      Bindery.solr.commit
      result
    end
  end
end
