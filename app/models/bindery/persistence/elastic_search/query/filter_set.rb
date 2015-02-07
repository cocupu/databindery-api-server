require 'jbuilder'
# Used by Elasticsearch::QueryBuilder to build queries and filters
class Bindery::Persistence::ElasticSearch::Query::FilterSet

  attr_accessor :type, :filters, :render_filters_as

  def self.build_appropriate(name,filter_params={})
    name = name.to_s
    if name.to_sym == :bool
      return Bindery::Persistence::ElasticSearch::Query::FilterTypes::Bool.new(name, filter_params)
    elsif name.to_sym == :multi_match
      return Bindery::Persistence::ElasticSearch::Query::FilterTypes::MultiMatch.new(name, filter_params)
    elsif name.to_sym == :query_string
      return Bindery::Persistence::ElasticSearch::Query::FilterTypes::QueryString.new(name, filter_params)
    elsif name.to_sym == :match_all
      return Bindery::Persistence::ElasticSearch::Query::FilterTypes::MatchAll.new(name, filter_params)
    else
      built_filter = Bindery::Persistence::ElasticSearch::Query::FilterSet.new(name, filter_params)
      if ['or','must','must_not','should'].include?(name)
        built_filter.render_filters_as = Array
      end
      return  built_filter
    end
  end

  def initialize(filter_type,filter_params={})
    @type = filter_type.to_s
    @filters = []
    add_filters(filter_params)
  end

  def add_filter(filter_type, filter_params={})
    new_filter = self.class.build_appropriate(filter_type, filter_params)
    @filters << new_filter
    return new_filter
  end

  def add_filters(filters_to_add)
    if filters_to_add.instance_of?(Array)
      @render_filters_as = Array
      @filters = filters + filters_to_add
    else
      unless filters_to_add.nil? || filters_to_add.empty?
        @filters << filters_to_add
      end
    end
  end

  def empty?
    filters.empty?
  end

  def as_json
    if empty?
      return {}
    else
      if render_filters_as == Array
        return {type => filters.as_json}
      elsif filters.count == 1
        return {type => filters.first.as_json}
      else
        filters_json = {}
        filters.each do |f|
          if f.instance_of?(Hash)
            filters_json.merge!(f)
          else
            filters_json[f.type] = f.filters.as_json
          end
        end
        return {type => filters_json}
      end
    end
  end

end