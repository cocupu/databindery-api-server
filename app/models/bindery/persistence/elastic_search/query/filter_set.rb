require 'jbuilder'
# Used by Elasticsearch::QueryBuilder to build queries and filters
class Bindery::Persistence::ElasticSearch::Query::FilterSet

  attr_accessor :must_match, :must_not_match, :should_match
  def initialize
    @must_match = []
    @must_not_match = []
    @should_match = []
  end

  def merge_into_request_body(request_body, location)
    json_to_insert = self.as_json
    if !json_to_insert.empty?
      request_body['query'] ||= {}
      request_body['query']['filtered'] ||= {}
      existing_content_at_target = request_body['query']['filtered'][location.to_s]
      if existing_content_at_target
        json_to_insert['bool'] ||= {}
        json_to_insert['bool']['must'] ||= []
        json_to_insert['bool']['must'] << existing_content_at_target
      end
      request_body['query']['filtered'][location.to_s] = json_to_insert
    end
    return request_body
  end

  def as_json
    json = {}
    ['must', 'must_not', 'should'].each do |bool_option|
      match_type = "#{bool_option}_match".to_sym
      unless self.send(match_type).empty?
        json['bool'] ||= {}
        json['bool'][bool_option] ||= []
        self.send(match_type).each do |match_arguments|
          json['bool'][bool_option] << {match: match_arguments}.as_json
        end
      end
    end
    return json
  end
end