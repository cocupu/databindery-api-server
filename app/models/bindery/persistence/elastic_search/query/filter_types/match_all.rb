# Primary use is to modify the .query and to set .parameters with values corresponding to an elasticsearch query_string query
class Bindery::Persistence::ElasticSearch::Query::FilterTypes::MatchAll < Bindery::Persistence::ElasticSearch::Query::FilterSet

  attr_accessor :parameters

  def initialize(filter_type='match_all', parameters={})
    @filter_type = 'match_all'
    @parameters = parameters.with_indifferent_access
    if @parameters.nil?
      @parameters = {}
    end
  end

  def type
    @filter_type
  end

  def empty?
    false
  end

  def as_json
    return {type => parameters}
  end
end
