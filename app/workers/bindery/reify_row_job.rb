class Bindery::ReifyRowJob
  include Resque::Plugins::Status

  def queue
    :reify_rows
  end

  # Expects 'row_content' and 'mapping_template_id' to be set
  def perform

    source_node_id = options['source_node']
    row_index = options['row_index']
    row_content = options['row_content']
    status = "Reifying data from row #{row_index} of node #{source_node_id}: #{row_content}"
    template = MappingTemplate.find(options['mapping_template'])
    pool = Pool.find(options["pool"])

    at(5, 100, "Loaded model and template. Reifying fields.")
    created = []
    template.model_mappings.each do |model_tmpl|
      model = Model.find(model_tmpl[:model_id])
      vals = {}
      model_tmpl[:field_mappings].each do |map|
        next unless map[:field]
        if letter?(map[:source])
          field_index = map[:source].ord - 65
        else
          field_index = map[:source].to_i
        end
        vals[map[:field]] = row_content[field_index]
      end
      n = Node.new(:data=>vals)
      n.spawned_from_node_id = source_node_id
      n.model = model
      n.pool = pool
      n.save!
      created << n
    end
    completed("Created node #{created.map {|n| n.persistent_id}}")
  end

  private

  def letter?(character)
    character =~ /[A-Za-z]/
  end

end