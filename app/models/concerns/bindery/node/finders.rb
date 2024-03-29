module Bindery::Node::Finders
  extend ActiveSupport::Concern
  include Bindery::Persistence::ElasticSearch::Common

  included do
    # Retrieves node by node_id.
    # Inspects the value to decide whether to use .find(node_id) or .find_by_persistent_id(node_id)
    def self.find_by_identifier(node_id)
      # really nasty way of testing whether node_id is an integer
      node_id_is_integer =  node_id.kind_of?(Integer) || node_id.to_i.to_s.length == node_id.length
      if node_id_is_integer
        node = self.find(node_id)
      else
        node = self.find_by_persistent_id(node_id)
      end
      return node
    end

    def self.query_elasticsearch(pool:, model:, query:, fields: nil)
      elasticsearch = Bindery::Persistence::ElasticSearch.client

      must_match_queries = [{'_bindery_model'=>model.id},{'_bindery_format'=>"Node"}]
      query.each_pair do |key, value|
        must_match_queries << {key => value}
      end
      query =  { bool: {must: must_match_queries.map{|mmq| {match:mmq } }}}
      search_body = { query: query }
      search_body[:fields] = fields if fields
      search_response = elasticsearch.search index: pool.to_param, body: search_body
      if fields
        search_response["hits"]["hits"].map {|hit| hit["fields"]}
      else
        search_response["hits"]["hits"].map {|hit| hit["_source"]}
      end
    end
  end

  # TODO grab this info out of solr.
  def find_association(association_id)
    association_id = association_id.to_s
    data[association_id] && (data[association_id] != "") ? data[association_id].map { |pid| Node.latest_version(pid) } : nil
  end

  def reify_association(type)
    find_association(type)
  end

  # Relies on a solr search to returns all Nodes that have associations pointing at this node
  def incoming(opts={})
    sleep 1
    elasticsearch_response = client.search index:pool.id, body: {query:{match:{"_bindery__associations"=> persistent_id}}}
    results = elasticsearch_response["hits"]["hits"].map{|d| Node.find_by_persistent_id(d['_id'])}
    results
  end
end