# Primary use is to modify the .query and to set .parameters with values corresponding to an elasticsearch query_string query
class Bindery::Persistence::ElasticSearch::Query::FilterTypes::QueryString < Bindery::Persistence::ElasticSearch::Query::FilterSet

  attr_accessor :parameters

  def initialize(filter_type='query_string', parameters={})
    @filter_type = 'query_string'
    @parameters = parameters.with_indifferent_access
  end

  def type
    @filter_type
  end

  def empty?
    query.nil? || query.empty?
  end

  def query
    @parameters[:query]
  end

  def query=(query)
    @parameters[:query] = query
  end

  def default_field=(default_field)
    @parameters[:default_field] = default_field
  end

  def as_json
    if empty?
      return {}
    else
      return {type => parameters}
    end
  end


end