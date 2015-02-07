# Follows the initializer profile of an ElasticSearch::Query::FilterSet but isnt' actually a subclass of it
# Does not support .add_filter.  Only supports adding values of .fields and .query
class Bindery::Persistence::ElasticSearch::Query::FilterTypes::MultiMatch #< Bindery::Persistence::ElasticSearch::Query::FilterSet

  attr_accessor :query, :multi_match_type, :fields, :tie_breaker, :minimum_should_match

  def initialize(filter_type='multi_match', filter_params={})
    @filter_type = filter_type.to_s
    if filter_params[:type]
      @multi_match_type = filter_params[:type]
    end
    [:query, :fields, :tie_breaker, :minimum_should_match].each do |attr|
      if filter_params[attr]
        self.instance_variable_set("@#{attr}".to_sym, filter_params[attr])
      end
    end
    @fields ||= []
  end

  def type
    @filter_type
  end

  def empty?
    query.nil? || query.empty? || fields.empty?
  end

  def as_json
    if empty?
      return {}
    else
      filter_json = {}
      if multi_match_type
        filter_json["type"] = multi_match_type
      end
      filter_json['fields'] = fields unless fields.empty?
      [:query, :tie_breaker, :minimum_should_match].each do |attr|
        if self.send(attr)
          filter_json[attr.to_s] = self.send(attr)
        end
      end
      return {type => filter_json}
    end
  end

end