# Provides an Elasticsearch Query
module Bindery
  module Persistence
    module ElasticSearch
      module Query
        class QueryBuilder

          attr_accessor :index, :type, :body, :fields, :query, :sort, :size, :from

          def initialize(opts={})
            @index = opts[:index]
            @type = opts[:type]
            @body = opts.fetch(:body, {})
            if opts[:sort].kind_of?(Array)
              @sort = []
            elsif opts[:sort]
              @sort = [opts[:sort]]
            else
              @sort = []
            end
            @fields = []
          end

          def body=(body)
            case body
              when String
                @body = JSON.parse(body)
              else
                @body = body.as_json
            end
          end

          def set_query(filter_type, filter_parameters)
            @query = Query::FilterSet.build_appropriate(filter_type,filter_parameters)
          end

          def query
            @query ||= FilterTypes::QueryString.new
          end

          def filters
            @filters ||= FilterTypes::Bool.new
          end

          def aggregations
            @aggregations ||= AggregationSet.new
          end
          delegate :add_facet, :add_aggregation, to: :aggregations

          def as_query
            query = as_json
            [:index,:type,:body].each do |param_key|
              if query.has_key?(param_key.to_s)
                query[param_key] = query.delete(param_key.to_s)
              end
            end
            query
          end

          def as_json
            json = super
            if type.nil?
              json.delete('type')
            end
            if fields.empty?
              json.delete('fields')
            else
              json['body']['fields'] = json.delete('fields')
            end
            json.delete('query')
            json.delete('filters')
            json.delete('sort')
            json.delete('aggregations')
            # json['body']['aggs'] = aggregations_json unless aggregations_json.nil? || aggregations_json.empty?

            unless aggregations.empty?
              json["body"].merge!(aggregations.as_json)
            end
            # Add query if any was set programatically
            # Note: This overwrites anything that was passed in the query within :body
            if query && !query.empty?
              if filters.empty?
                json['body']['query'] = query.as_json
              else
                json['body']['query'] ||= {}
                json['body']['query']['filtered'] ||= {}
                json['body']['query']['filtered']['query'] = query.as_json
              end
            end

            # Add filters if any are set
            unless filters.empty?
              json['body']['query'] ||= {}
              json['body']['query']['filtered'] ||= {}
              json['body']['query']['filtered']['filter'] = filters.merge_existing_filters(json['body']['query']['filtered']['filter'])
            end

            unless sort.empty?
              json['body']['sort'] = sort.as_json
            end
            json
          end

        end
      end
    end
  end
end
