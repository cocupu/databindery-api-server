module Bindery
  module Persistence
    module Dat
      class Repository < ::Dat::Repository
        attr_accessor :pool, :dir, :cached_models

        def initialize(pool:, dir:nil)
          raise ArgumentError, "pool must be a DatBackedPool object" unless pool.instance_of?(::DatBackedPool)
          @dir = dir ? dir : pool.ensure_dat_location
          @pool = pool
        end

        # Either export all of the dat rows or run a diff
        # @option [String] index_name of the elasticsearch index to update
        # @option [String] from commit hash to diff from
        # @option [String] to commit hash to diff up to
        def index(index_name: nil, from: nil, to: nil)
          if index_name
            pool.__elasticsearch__.require_index_to_be_in_pool!(index_name)
          else
            index_name = pool.to_param
          end
          if from
            diff_in_batches(from, to) do |diff_rows|
              bulk_index(diff_rows, index_name: index_name)
            end
          else
            datasets.each do |dataset_name|
              export_in_batches(dataset: dataset_name) do |rows|
                bulk_index(rows, index_name: index_name, model_name: dataset_name)
              end
            end
          end
        end

        # Index the +rows+ into elasticsearch
        # @param [Array] rows to index
        # @option [String] index_name of the elasticsearch index to update
        # @option [String] model_name to use as elasticsearch type -- not necessary if rows are in :diff format
        # @option [String] row_format of the rows -- either :export (output from running `dat export --full`) or :diff (output from running `dat diff`)
        def bulk_index(rows, index_name:, model_name: nil)
          model = nil
          bulk_actions = rows.map do |row|
            unless row.nil?
              begin
                parsed_row = ::DatRow.parse(row, pool: pool)
                raise ArgumentError, 'you must provide a model_name when the rows are :export format' unless model_name || parsed_row.row_format == :diff
                # dat diff can contain rows from multiple datasets
                # so set the model_name based on that
                if parsed_row.row_format == :diff
                  model_name = parsed_row.row_json['versions'].last['dataset']
                end
                model = find_or_create_model(model_name)
                parsed_row.model = model
                parsed_row.as_elasticsearch_bulk_action(index_name: index_name)
              rescue JSON::ParserError
                # Bad json. do nothing
              end
            end
          end
          Bindery::Persistence::ElasticSearch.client.bulk body: bulk_actions
        end

        private

        # find or create model based on model_name
        # * singularizes model names -- content from 'proteins' dataset gets a model called 'protein'
        # * caches models in order to minimize SQL queries while bulk indexing
        # Note: Model.find_or_create_by(code: model_name) does not work because
        # we only want to search by :code but if we need to create a new Model
        # we need to provide both :code and :name
        # Note: singularizing model names is necessary because having a model
        # called 'tree' and a model called 'trees ' would violate uniqueness
        # constraints.
        def find_or_create_model(model_name)
          self.cached_models ||= {}
          singular_model_name = model_name.singularize
          # if the correct model was loaded on a previous pass, reuse it instead of loading again
          unless cached_models[singular_model_name]
            model = Model.create_with(name: singular_model_name.humanize).find_or_create_by(pool: pool, code: singular_model_name)
            cached_models[singular_model_name] = model
          end
          return cached_models[singular_model_name]
        end
      end
    end
  end
end
