class Bindery::ReifyHashJob
  include Resque::Plugins::Status

  def queue
    :reify_hashes
  end

  # Expects 'row_content' and 'mapping_template_id' to be set
  def perform
    pool_id = options["pool"]
    model_id = options['model']
    source_node_id = options['source_node']
    row_index = options['row_index']
    row_content = options['row_content']
    status = "Reifying data from row #{row_index} of node #{source_node_id}: #{row_content}"
    at(50, 100, status)
    n = Node.new(:data=>row_content)
    n.spawned_from_node_id = source_node_id
    n.model_id = model_id
    n.pool_id = pool_id
    n.save!
    completed("Created node #{n.persistent_id}")
  end

end