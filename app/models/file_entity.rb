module FileEntity

  def self.build(opts={})
    file_entity = Node.new( opts )
    file_entity.extend FileEntity
  end
  # Creates a FileEntity corresponding to a remote file with the given characteristics.
  # Required parameters:
  #   pool <Pool>
  #   binding <String> that is the URI uniquely identifying the remote file
  # Currently Assumes:
  #   * the remote file is in Amazon S3
  #   * the S3 object is in the given Pool's default bucket
  # @example
  #   file_entity = FileEntity.register(my_pool, :data=>{"bucket"=>"f542aab0-66e4-0130-8d40-442c031da886",storage_location_id"=>"/f542aab0-66e4-0130-8d40-442c031da886/uploads%2F20130305T1425Z_eaf29caae12b6d4a101297b45c46dc2a%2FDSC_0549-3.jpg", "file_name"=>"DSC_0549-3.jpg", "file_size"=>"471990", "mime_type"=>"image/jpeg", "binding"=>"https://s3.amazonaws.com/f542aab0-66e4-0130-8d40-442c031da886/uploads%2F20130305T1425Z_eaf29caae12b6d4a101297b45c46dc2a%2FDSC_0549-3.jpg"})
  def self.register(pool, opts={})
    opts = opts.with_indifferent_access
    opts[:data] = {} unless opts[:data]
    opts[:data]["mime_type"] = opts[:data][:filetype] unless opts[:data][:filetype].nil?
    file_entity = Node.new( opts.slice(:data, :associations, :binding, :persistent_id, :storage_location_id) )
    file_entity.model = Model.file_entity
    file_entity.convert_data_field_codes_to_id_strings!
    file_entity.pool = pool
    file_entity.extend FileEntity
    file_entity.file_entity_type = "S3"
    file_entity.content_type
    if file_entity.storage_location_id.include?(file_entity.bucket)
      file_entity.storage_location_id = Bindery::Storage::S3.key_from_filepath(file_entity.storage_location_id,bucket:file_entity.bucket)
    end
    # If a binding URL was not provided, generate it based on node info before saving.
    file_entity.binding = pool.file_store_type.binding_url_from_node_info(file_entity) unless file_entity.binding
    file_entity.model = Model.file_entity
    file_entity.save!
    file_entity.send(:set_metadata)
    return file_entity
  end

  # Creates an un-saved FileEntity with all of the desired info for creating a remote file (ie. persistent_id and storage_location_id).
  # This is primarily for use when preparing to upload content to remote storage like Amazon S3.  After successful remote uploads, a real FileAsset will be persisted using the #register method (often via the FileEntitiesController.s3_confirm method)
  # Required parameters:
  #   pool <Pool>
  # @example
  #   file_entity = FileEntity.placeholder_for_upload(my_pool, :data=>{"filepath"=>"/f542aab0-66e4-0130-8d40-442c031da886/uploads%2F20130305T1425Z_eaf29caae12b6d4a101297b45c46dc2a%2FDSC_0549-3.jpg", "filename"=>"DSC_0549-3.jpg", "filesize"=>"471990", "filetype"=>"image/jpeg", "binding"=>"https://s3.amazonaws.com/f542aab0-66e4-0130-8d40-442c031da886/uploads%2F20130305T1425Z_eaf29caae12b6d4a101297b45c46dc2a%2FDSC_0549-3.jpg"})
  def self.placeholder_for_upload(pool, opts={})
    #opts = opts.with_indifferent_access
    #opts[:data] = {} unless opts[:data]
    #opts[:data]["content-type"] = opts[:data][:mime_type] unless opts[:data][:mime_type].nil?
    #file_entity = Node.new( opts.slice(:data, :associations, :binding) )
    file_entity = Node.new
    file_entity.pool = pool
    file_entity.extend FileEntity
    file_entity.file_entity_type = "S3"
    file_entity.model = Model.file_entity
    file_entity.generate_uuid
    file_entity.storage_location_id = file_entity.pool.file_store_type.generate_storage_location_id(file_entity)
    #file_entity.save!
    return file_entity
  end

  def model
    Model.file_entity
  end
  
  def file_entity_type=(name)
    set_field_value('file_entity_type', name, find_by: :code)
  end

  def file_entity_type
    field_value('file_entity_type', find_by: :code)
  end
  
  def file_name=(name)
    set_field_value('file_name', name, find_by: :code)
  end

  def file_name
    field_value('file_name', find_by: :code)
  end

  def content_type=(name)
    set_field_value('content_type', name, find_by: :code)
  end

  def content_type
    value = field_value('content_type', find_by: :code)
    if value.nil?
      return self.content_type = file_type.capitalize
    else
      return value
    end
  end
  
  def file_size=(name)
    set_field_value('file_size', name, find_by: :code)
  end

  def file_size
    field_value('file_size', find_by: :code)
  end

  def bucket=(name)
    set_field_value('bucket', name, find_by: :code)
  end

  def bucket
    value = field_value('bucket', find_by: :code)
    if value.nil?
      return self.bucket = pool.persistent_id
    else
      return value
    end
  end
  
  # Returns an authorized S3 url for the corresponding S3 content
  # Accepts all the same parameters as AWS::S3::S3Object.url_for
  # Default Values for options Hash:
  #   * method: :read
  #   * The url authorization expires afte 1.5 hours.
  #   * response_content_disposition: "inline; filename=#{file_name}"
  def s3_url(method=:read, options={})
    default_options = {response_content_disposition: "inline; filename=#{file_name}", expires: 60 * 60 * 1.5}
    options = default_options.merge(options)
    return pool.default_file_store.get(bucket, storage_location_id).url_for(method, options)
  end
  
  # The id used to find file in file store (ie. S3 object key)
  def storage_location_id
    value = field_value('storage_location_id', find_by: :code)
    if value.nil?
      return self.storage_location_id = self.generate_uuid   # make sure persistent_id is set & use that
    else
      return value
    end
  end
  
  def storage_location_id=(new_id)
    set_field_value('storage_location_id', new_id, find_by: :code)
  end

  def mime_type
    # we can get this from s3, but keep it cached locally so we know what kind of presentation to use
    field_value('mime_type', find_by: :code)
  end

  def mime_type=(mime_type)
    set_field_value('mime_type', mime_type, find_by: :code)
  end

  # fetch from s3
  def content
    s3_obj.read
  end

  # Store in s3
  def content=(file)
    @content_changed = true
    @content = file
  end

  
  def save
    store_content
    super
  end

  def save!
    store_content
    super
  end
  
  #
  # Handling local tmp file
  #
  
  # Pulls the file from file store and stores in local tmp file for processing
  def generate_tmp_file
    FileUtils.mkdir_p(local_tmp_dir) unless File.exists?(local_tmp_dir)
    #TODO avoid name collision
    stored = File.new(local_file_pathname, 'wb')
    stored.write s3_obj.read
    stored.close
    # Download and write the file in blocks off the HTTP Response (see S3Object.read in aws-sdk docs)
    # File.open(local_file_pathname, 'w') do |file|
    #   s3_obj.read do |chunk|
    #     file.write(chunk)
    #   end
    #   file
    # end
  end
  
  def local_file_pathname
    File.join(local_tmp_dir, file_key)
  end
  
  def local_tmp_dir
    #Platform independant way of showing a File path. Empty String ('') means the root
    File.join('', 'tmp', 'cocupu', Rails.env)
  end
  
  def file_key
    raise "Can't make a key until the record is saved" unless persistent_id
    "#{persistent_id}.#{filename_extension}"
  end
  
  def filename_extension
    /\.([^.]+)$/.match(file_name)[1]
  end
  
  def audio?
    ["audio/mp3", "audio/mpeg"].include? self.mime_type
  end
  
  def video?
    ["video/mpeg", "video/mp4", "video/x-msvideo", "video/avi", "video/quicktime"].include? self.mime_type
  end
  
  def image?
    ["image/png","image/jpeg", 'image/jpg', 'image/bmp', "image/gif"].include? self.mime_type
  end
  
  def pdf?
    ["application/pdf"].include? self.mime_type
  end
  
  def spreadsheet?
    ["application/vnd.ms-excel", "application/vnd.oasis.opendocument.spreadsheet", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"].include? self.mime_type
  end

  def file_type
    if audio?
      return "audio"
    elsif video?
      return "video"
    elsif image?
      return "image"
    elsif pdf?
      return "pdf"
    elsif spreadsheet?
      return "spreadsheet"
    else
      return "generic"
    end
  end

  def as_json(opts=nil)
    h = super
    h["spawnable"] = spreadsheet?
    h["file_entity"] = true
    h["file_type"] = file_type
    h
  end

  def to_solr
    solr_doc = super
    [:mime_type,:content_type,:file_type,:storage_location_id,:file_size,:file_entity_type,:file_name].each do |method|
      solr_doc[method.to_s+"_ssi"] = self.send(method)
    end
    solr_doc
  end

  # Set metadata (ie. filename for insertion into Content-Disposition) on object in remote file store
  def set_metadata
    s3_obj.metadata["filename"] = file_name
    s3_obj.metadata["bindery-pid"] = persistent_id
  end


  private

  def s3_obj
    @s3_object ||= pool.default_file_store.get(bucket, storage_location_id)
  end

  # Stores content in bucket (usually bucket name is the pool's persistent_id) with id of storage_location_id (usually Node persistent_id)
  # After storing the object, sets metadata like Content-Disposition
  def store_content
    if @content_changed
      @s3_object = pool.default_file_store.put(bucket, storage_location_id, @content)
      set_metadata
    end
    @content_changed=false
  end

end
