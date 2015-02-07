module Bindery
  class PoolImporter

    attr_accessor :pool

    # Assumes directory containing
    #   pool.json
    #   models.json
    #   nodes.json
    # Note: the pool.json is not required if you provide a pool in the arguments
    # @example
    #   import_from('my_import_dir', pool: the_pool)
    def import_from(directory_path, identity, opts={})
      @pool = opts[:pool]
      @pool = import_pool(File.join(directory_path,'pool.json'), identity, opts) unless @pool
      models = import_models(File.join(directory_path,'models.json'),pool)
      node_import_results = import_nodes(File.join(directory_path,'nodes.json'), models, pool)
      puts node_import_results
      return node_import_results
    end

    def import_pool(path_to_json, identity, opts={})
      pool_json = JSON.parse(File.open(path_to_json).first)
      selected_attributes = pool_json.select {|k,v| ['name','description','short_name','persistent_id'].include?(k) }
      selected_attributes['owner_id'] = identity.id
      if opts[:force_create_new]
        selected_attributes.delete('persistent_id') unless Pool.find_by_persistent_id(selected_attributes['persistent_id']).nil?
        selected_attributes.delete('short_name') unless Pool.find_by_short_name(selected_attributes['short_name']).nil?
        return Pool.create(selected_attributes)
      else
        return Pool.find_or_create_by(selected_attributes)
      end
    end

    # Eventually, this should try to re-use models by doing a lookup by model URI
    #
    # Importing fields -- the trick: need to resolve references, which are currently by (old pool's) model id
    # * First create all of the models, without any fields.  The old model URIs will be applied to the new models, so you can still find them
    # * replace :references values in all fields with the new model ids before importing Fields
    # ** if a Field references a nonexistent model...
    # * Import all of the fields, ensuring that they get uris, and retain a hash that allows you to find the new field's URI by its old id
    # * add fields to imported models, using old ids to look up the new fields by their URIs
    # * set label_field_id on each imported model using old ids to look up new fields by their uris
    def import_models(path_to_json, pool)
      model_attributes_to_ignore = ['id','fields','created_at','updated_at','identity_id','pool_id','associations','label_field_id']
      field_attributes_to_ignore = ['id','created_at','updated_at']
      models_json = []
      File.open( path_to_json ).each {|json| models_json << JSON.parse(json)}

      # First, Import the models without their fields
      models_by_uri = {}
      models_json.each do |model_json|
        selected_attributes = model_json.reject {|k,v| model_attributes_to_ignore.include?(k) }
        models_by_uri[selected_attributes['uri']] = Model.find_or_create_by(selected_attributes.merge(pool_id:pool.id,identity_id:pool.owner_id))
      end

      # Second, Import the Fields, resolving any :references values, and add the Fields to their Models
      models_json.each do |model_json|
        model = models_by_uri[model_json['uri']]
        model_json["fields"].each do |field_json|
          selected_attributes = field_json.reject {|k,v| field_attributes_to_ignore.include?(k) }
          if selected_attributes['references'] && models_by_uri.keys.include?(selected_attributes['references'])
            selected_attributes['references'] = models_by_uri[selected_attributes['references']].id
          end
          # If no URI was set before, set it to a URI that references the original Field in the source Pool
          if selected_attributes['uri'].nil?
            selected_attributes['uri'] = "http://api.databindery.com/api/v1/pools/#{model_json['pool_id']}/fields/#{field_json['id']}"
          end
          created_field = Field.find_or_create_by(selected_attributes)
          model.fields << created_field
          if model_json['label_field_id'] == field_json["id"]
            model.label_field = created_field
          end
        end
        model.save
      end
      return models_by_uri
    end

    def import_nodes(path_to_json, models_by_uri, pool)
      nodes_by_model = {}
      file = File.open(path_to_json)
      file.each_line do |line|
        begin
          json = JSON.parse(line)
          nodes_by_model[json["bindery_model_uri"]] ||= []
          nodes_by_model[json["bindery_model_uri"]] << json
        rescue => e
          puts "Bad line: "+ line
          nodes_by_model["errors"] ||= []
          nodes_by_model["errors"] << line
        end
      end
      converted_data = []
      import_results = []
      models_by_uri.each_pair do |uri,model|
        nodes_by_model.fetch(uri,[]).each do |entry|
          # This was used when node.data used field id strings as keys
          # converted_data << model.convert_data_field_codes_to_id_strings(entry)
          converted_data << entry
        end
        import_results << ::Node.bulk_import_data(converted_data, pool, model)
        converted_data = []
      end
      return import_results
    end

  end
end
