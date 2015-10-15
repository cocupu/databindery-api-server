class SqlBackedPool < Pool

  has_many :nodes, :dependent => :destroy, foreign_key: 'pool_id' do
    def head
      pool_pids = map {|n| n.persistent_id}.uniq
      return pool_pids.map {|pid| Node.latest_version(pid)}
    end
  end
  # A more efficient way to load complete head state of the pool
  def nodes_head(args = {})
    return node_pids.map {|pid| Node.latest_version(pid)}
  end

  def node_pids
    ActiveRecord::Base.connection.execute("SELECT DISTINCT persistent_id FROM nodes WHERE pool_id = #{self.id}").values
  end

  def update_index
    node_pids.each do |node_pid|
      node_version_id = Node.latest_version_id(node_pid)
      Bindery::Persistence::ElasticSearch::Node::NodeIndexer.perform_async(node_version_id)
    end
    logger.info("Reindexing #{node_pids.count} nodes in Pool #{self.id}.")
  end

end
