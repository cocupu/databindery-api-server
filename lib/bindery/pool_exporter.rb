module Bindery
  class PoolExporter


    # Work In Progress!
    # @example export Nodes with pool_id and data
    #   pool.export(attributes:[:pool_id, :data])
    def export(pool, opts={})
      if  opts[:format] && opts[:format] != :json
        raise ArgumentError, "Export currently only supports json.  You requested #{opts[:format]}"
      end
      basepath = basepath_for_export(pool)
      setup_export_dir(basepath)
      filepath_for_pool = File.join(basepath,"pool.json")
      filepath_for_models = File.join(basepath,"models.json")
      filepath_for_nodes = File.join(basepath,"nodes.json")

      File.open(filepath_for_pool,"w") do |f|
        f << convert_pool(pool).to_json
      end
      File.open(filepath_for_models,"w") do |f|
        pool.models.each do |model|
          f << convert_model(model).to_json
          f << "\n"
        end
      end
      # attributes_to_export= opts.fetch(:attributes,[:data])
      File.open(filepath_for_nodes,"w") do |f|
        pool.node_pids.each do |node_pid|
          node = ::Node.latest_version(node_pid)
          f << convert_node_data(node).to_json
          f << "\n"
        end
      end
      return basepath
    end

    def convert_pool(pool)
      pool.as_json
    end

    # Converts model info to json for export
    # Injects "uri" value
    # Ignores the :associations attribute, since it repeats content from :fields
    # Within "fields", replaces all :references values in Fields with URIs for those models instead of the Model ids
    def convert_model(model)
      # model_uri = "http://api.databindery.com/api/v1/pools/#{model.pool_id}/models/#{model.id}"
      if model.uri.nil?
        model.uri = model.to_uri
      end
      map_model_id_to_uri(model.id,model.uri)
      model_json = model.as_json
      model_json.delete('associations')
      model_json['fields'] = []
      model.fields.each do |field|
        field_json = field.as_json
        if field.references
          field_json['references'] = Model.find(field.references).to_uri
        end
        model_json['fields'] << field_json
      end
      return model_json
    end

    # Exports the content of node.data as the node
    # Converts field ids to field codes for increased portability/redability
    # Inserts a bindery_model_id into the data so the nodes can be re-imported into new Pools
    def convert_node_data(node)
      field_map = node.model.map_field_codes_to_id_strings.invert
      converted_data = node.data.dup
      field_map.each_pair do |field_id_string,field_code|
        if converted_data.has_key?(field_id_string)
          converted_data[field_code] = converted_data.delete(field_id_string)
        end
      end
      converted_data["bindery_model_uri"] = uri_for_model(node.model_id)
      # node.data.each_pair do |k,v|
      #   converted_data[field_map[k]] = v
      # end
      converted_data
    end

    def uri_for_model(model_id)
      @model_id_to_uri_map[model_id]
    end

    def map_model_id_to_uri(model_id,uri)
      @model_id_to_uri_map ||= {}
      @model_id_to_uri_map[model_id] = uri
    end

    def basepath_for_export(pool)
      File.join("tmp",pool.persistent_id,pool.short_name+"_#{DateTime.now.strftime("%FT%H%M")}")
    end

    def setup_export_dir(export_dir_path)
      FileUtils::mkdir_p export_dir_path
    end

  end
end