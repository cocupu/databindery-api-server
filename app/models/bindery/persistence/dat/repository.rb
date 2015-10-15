module Bindery
  module Persistence
    module Dat
      class Repository < ::Dat::Repository
        attr_accessor :pool, :dir

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
          index_name ||= pool.to_param
          if from
            diff(from, to)
          else
            datasets.each do |dataset_name|
              export_in_batches(dataset: dataset_name) do |rows|
                bulk_index(rows, index_name: index_name, model_name: dataset_name)
              end
            end
          end
        end

        def is_dat_repository?
          return false unless File.exists?(dir)
          begin
            status
          rescue
            return false
          end
          true
        end

        # Index the +rows+ into elasticsearch
        # @param [Array] rows to index
        # @option [String] index_name of the elasticsearch index to update
        # @option [String] model_name to use as elasticsearch type -- not necessary if rows are in :diff format
        # @option [String] row_format of the rows -- either :export (output from running `dat export --full`) or :diff (output from running `dat diff`)
        def bulk_index(rows, index_name:, model_name: nil)
          raise ArgumentError, 'you must provide a model_name unless the rows are :diff format' unless model_name || row_format == :diff
          model = nil
          bulk_actions = rows.map do |row|
            unless row.nil?
              begin
                parsed_row = ::DatRow.parse(row, pool: pool)
                # dat diff can contain rows from multiple datasets
                # so set the model_name based on that
                if parsed_row.row_format == :diff
                  model_name = parsed_row.row_json['versions'].last['dataset']
                end
                # if the correct model was loaded on a previous pass, reuse it instead of loading again
                if model.nil? || model.code != model_name
                  # find_or_create_by :code does not work because
                  # we only want to search by :code but need to provide :code and :name on create
                  model = pool.models.where(code: model_name).first
                  model ||= pool.models.create(code: model_name, name: model_name.humanize)
                end
                parsed_row.model = model
                parsed_row.as_elasticsearch_bulk_action(index_name: index_name)
              rescue JSON::ParserError
                # Bad json. do nothing
              end
            end
          end
          Bindery::Persistence::ElasticSearch.client.bulk body: bulk_actions
        end

        # @param [Hash] row JSON for the row
        # @option [String] index_name of the elasticsearch index to update
        # @option [String] model_name to use as elasticsearch type
        # @option [String] row_format -- either :export (output from running `dat export --full`) or :diff (output from running `dat diff`)
        # def self.row_to_elasticsearch(row, pool:, model:, row_format: :export)
        #   raise ArgumentError, 'row_format must be either :diff or :export' unless [:diff, :export].include?(row_format)
        #   # if row_format == :diff
        #   #   row_data = row['versions'].last
        #   # else
        #   #   row_data = row['value']
        #   # end
        #   # ::DatRow.new(pool: pool, model: model, data: row_data, row_json: row, persistent_id:row['key']).as_elasticsearch
        #   parsed_row = ::DatRow.parse(row, pool: pool, model: model, row_format: row_format)
        #   parsed_row.as_elasticsearch
        # end

      end
    end
  end
end
