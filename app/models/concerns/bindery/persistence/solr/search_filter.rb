module Bindery::Persistence::Solr::SearchFilter
  extend ActiveSupport::Concern

  module ClassMethods
    def apply_solr_params_for_filters(filters, solr_parameters, user_parameters)
      unless filters.empty?
        solr_parameters[:fq] ||= []
        grant_filter_solr_params = {:fq=>[]}
        filters.each do |filter|
          if filter.filter_type == "GRANT"
            filter.apply_solr_params(grant_filter_solr_params, user_parameters)
          else
            filter.apply_solr_params(solr_parameters, user_parameters)
          end
        end
        unless grant_filter_solr_params[:fq].empty?
          solr_parameters[:fq] <<  grant_filter_solr_params[:fq].join(" OR ")
        end
      end
      return solr_parameters, user_parameters
    end
  end

  def apply_solr_params(solr_parameters, user_parameters)
    solr_parameters[:fq] ||= []
    if filter_type == "GRANT"
      solr_parameters[:fq] << values.map {|v| "#{Node.solr_name(field)}:#{quoted_query_value(v)}" }.join(" OR ")
    else  # filter_type == "RESTRICT"
      if values.length > 1
        query = values.map {|v| "#{Node.solr_name(field)}:#{quoted_query_value(v)}" }.join(" OR ")
        solr_parameters[:fq] << "#{operator}(#{query})"
      else
        v = values.first
        solr_parameters[:fq] << "#{operator}#{Node.solr_name(field)}:#{quoted_query_value(v)}"
      end
    end
    solr_parameters
  end

  def quoted_query_value(value)
    if value == "*"
      value
    else
      "\"#{value}\""
    end
  end

end
