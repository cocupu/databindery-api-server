module Bindery::Persistence::ElasticSearch::SearchFilter
  extend ActiveSupport::Concern

  module ClassMethods

    def apply_query_params_for_filters(filters, query_builder, user_parameters)
      apply_elasticsearch_params_for_filters(filters, query_builder, user_parameters)
    end

    def apply_elasticsearch_params_for_filters(filters, query_builder=Bindery::Persistence::ElasticSearch::Query::QueryBuilder.new, user_parameters={})
      filters.each do |filter|
        filter.apply_elasticsearch_params(query_builder, user_parameters)
      end
      return query_builder, user_parameters
    end
  end

  def apply_query_params(query_builder, user_parameters)
    apply_elasticsearch_params(query_builder, user_parameters)
  end

  def apply_elasticsearch_params(query_builder=Bindery::Persistence::ElasticSearch::Query::QueryBuilder.new,user_parameters={})
    unless query_builder.instance_of?(Bindery::Persistence::ElasticSearch::Query::QueryBuilder)
      raise ArgumentError, "query_builder must be an instance of Bindery::Persistence::ElasticSearch::Query::QueryBuilder"
    end
    # query_builder[:fq] ||= []
    if filter_type == "GRANT"
      values.each do |value|
        query_builder.filters.add_should_match({field.code => value}, context: :filter )
      end
    else  # filter_type == "RESTRICT"
      if operator == "-"
        values.each do |value|
          query_builder.filters.add_must_not_match({field.code => value}, context: :filter )
        end
      else
        if values.length > 1
          or_filter = query_builder.filters.must.add_filter(:or)
          values.each do |value|
            or_filter.add_filter(:query).add_filter(:match,{field.code => value})
          end
        else
          v = values.first
          query_builder.filters.add_must_match({field.code => v}, context: :filter)
        end
      end
    end
    return query_builder,user_parameters
  end

  def quoted_query_value(value)
    if value == "*"
      value
    else
      "\"#{value}\""
    end
  end

end
