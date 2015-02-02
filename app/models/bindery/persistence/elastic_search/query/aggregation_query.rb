module Bindery
  module Persistence
    module ElasticSearch
      module Query
        class AggregationQuery

          attr_accessor :name, :type, :parameters

          # If no field name is provided in opts[:parameters][:field], the name will be used
          # If no :type is provided in opts[:type], it defaults to 'terms' aggregation type
          #
          # @example Relying on defaults
          # AggregationQuery.new("first_name")
          # => #<AggregationQuery: @parameters={:field=>"first_name"}, @name="first_name", @type="terms">
          #
          # @example Explicitly setting type and field name
          # AggregationQuery.new("prices", type:'histogram', parameters:{field_name:'price', interval:'50'})
          # => #<AggregationQuery: @parameters={:field=>"price", interval:'50'}, @name="prices", @type="histogram">
          def initialize(name, opts={})
            @parameters = opts.fetch(:parameters, {})
            if opts[:field]
              field = opts[:field]
            end
            self.name = name
            @type = opts.fetch(:type, 'terms')
          end

          # If no :field is set in opts[:parameters], the name will be used
          def name=(name)
            @name = (name)
            unless parameters.has_key?(:field)
              parameters[:field] = name
            end
          end

          # Sets the field that the histogram will search against
          def field=(field_name)
            parameters[:field] = field_name
          end

          def field
            parameters[:field]
          end

          # Aggregations can have sub-aggregations
          # Use this method to add them.
          def aggregations
            @aggregations ||= AggregationSet.new
          end

          def as_json
            {name => {type => parameters}}.as_json
          end
        end
      end
    end
  end
end
