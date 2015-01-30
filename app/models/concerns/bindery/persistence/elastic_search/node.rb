module Bindery::Persistence::ElasticSearch::Node

  included do
    # Schedule a job to create the elasticsearch type
    after_save { NodeIndexer.perform_async(self.pool.to_param, self.to_param, self.to_elasticsearch) }
    # Schedule a job to destroy associated elasticsearch artifacts
    after_destroy { NodeDestroyer.perform_async(self.pool.to_param, self.to_param) }
  end

  def to_elasticsearch

  end

  class NodeIndexer
    include Sidekiq::Worker

    def perform(index_name, type_name, mapping)
      # Bindery::Persistence::ElasticSearch::Model.create_elasticsearch_type(index_name, type_name, mapping)
    end
  end

  class NodeDestroyer
    include Sidekiq::Worker

    def perform(index_name, type_name, mapping)
      # Bindery::Persistence::ElasticSearch::Model.create_elasticsearch_type(index_name, type_name, mapping)
    end
  end
end