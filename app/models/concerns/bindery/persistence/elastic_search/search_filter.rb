module Bindery::Persistence::ElasticSearch::SearchFilter
  extend ActiveSupport::Concern

  module ClassMethods

    def apply_query_params_for_filters(filters, query_parameters, user_parameters)
      apply_elasticsearch_params_for_filters(filters, query_parameters, user_parameters)
    end

    def apply_elasticsearch_params_for_filters(filters, elasticsearch_parameters, user_parameters)
      unless filters.empty?
        elasticsearch_parameters[:fq] ||= []
        grant_filter_elasticsearch_params = {:fq=>[]}
        filters.each do |filter|
          if filter.filter_type == "GRANT"
            filter.apply_elasticsearch_params(grant_filter_elasticsearch_params, user_parameters)
          else
            filter.apply_elasticsearch_params(elasticsearch_parameters, user_parameters)
          end
        end
        unless grant_filter_elasticsearch_params[:fq].empty?
          elasticsearch_parameters[:fq] <<  grant_filter_elasticsearch_params[:fq].join(" OR ")
        end
      end
      return elasticsearch_parameters, user_parameters
    end
  end

  def apply_query_params(elasticsearch_parameters, user_parameters)
    apply_elasticsearch_params(elasticsearch_parameters, user_parameters)
  end

  def apply_elasticsearch_params(elasticsearch_parameters, user_parameters)
    elasticsearch_parameters[:fq] ||= []
    if filter_type == "GRANT"
      elasticsearch_parameters[:fq] << values.map {|v| "#{Node.field_name_for_elasticsearch(field)}:#{quoted_query_value(v)}" }.join(" OR ")
    else  # filter_type == "RESTRICT"
      if values.length > 1
        query = values.map {|v| "#{Node.field_name_for_elasticsearch(field)}:#{quoted_query_value(v)}" }.join(" OR ")
        elasticsearch_parameters[:fq] << "#{operator}(#{query})"
      else
        v = values.first
        elasticsearch_parameters[:fq] << "#{operator}#{Node.field_name_for_elasticsearch(field)}:#{quoted_query_value(v)}"
      end
    end
    elasticsearch_parameters
  end

  def quoted_query_value(value)
    if value == "*"
      value
    else
      "\"#{value}\""
    end
  end

end
