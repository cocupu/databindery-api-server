# Provides an Elasticsearch Query
module Bindery
  module Persistence
    module ElasticSearch
      module Query
        class QueryBuilder

          attr_accessor :index, :type, :body, :fields

          def initialize(opts={})
            @index = opts[:index]
            @type = opts[:type]
            @body = opts.fetch(:body, {})
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

          def query
            @query ||= FilterSet.new
          end

          def filters
            @filters ||= FilterSet.new
          end

          def multi_match
            @multi_match ||= MultiMatchQuery.new
          end

          def aggregations
            @aggregations ||= AggregationSet.new
          end
          delegate :add_facet, :add_aggregation, to: :aggregations

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
            json['body'] = query.merge_into_request_body(json['body'], :query)
            json['body'] = filters.merge_into_request_body(json['body'], :filter)
            json.merge!(aggregations.as_json)
            json
          end

        end
      end
    end
  end
end
