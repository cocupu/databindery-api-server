class DatBackedPool < Pool

  def dat
    @dat ||= Bindery::Persistence::Dat::Repository.new(pool: self, dir: ensure_dat_location)
  end

  def nodes
    raise NotImplementedError
    # dat.export.map {|row| DatBackedNode.parse(row) }
  end

  def nodes_io
    raise NotImplementedError
    # exportio.each_line do |row|
    #   yield DatBackedNode.parse(row)
    # end
  end

  def update_index
    dat.index
  end

  def ensure_dat_location
    self.dat_location ||= default_dat_location
  end

  private

  def default_dat_location
    raise RuntimeError, 'Cannot determine dat location for a pool that is not persisted.' unless persisted?
    File.join dat_root, self.to_param
  end

  def dat_root
    File.join Rails.root.to_s, 'dat'
  end

end
