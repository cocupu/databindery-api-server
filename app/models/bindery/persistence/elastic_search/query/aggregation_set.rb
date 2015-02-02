module Bindery
  module Persistence
    module ElasticSearch
      module Query
        class AggregationSet
          attr_accessor :aggregations
          def initialize(aggregations=[])
            @aggregations = aggregations
          end

          def add_facet(name, options={})
            options.merge!(type:'terms')
            aggregations << AggregationQuery.new(name, options)
          end

          def add_aggregation(name, options={})
            aggregations << AggregationQuery.new(name, options)
          end

          def <<(aggregation)
            raise ArgumentError unless aggregation.instance_of?(AggregationQuery)
            aggregations << aggregation
          end

          def empty?
            aggregations.empty?
          end

          def as_json
            if empty?
              return {}
            else
              json = {'aggs'=>{}}
              aggregations.each do |aggregation|
                json['aggs'].merge!(aggregation.as_json)
              end
              return json
            end
          end
        end
      end
    end
  end
end
