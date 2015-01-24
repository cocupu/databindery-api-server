module Bindery::Node::HasFiles
  extend ActiveSupport::Concern

  included do
    before_save :update_file_ids
  end

  # Stores file in an S3 bucket named after its Pool's persistent_id
  def attach_file(file_name, file)
    file_node = Node.new
    file_node.extend FileEntity
    file_node.file_name = file_name
    file_node.pool= pool
    file_node.model= Model.file_entity
    raise StandardError, "You can't add files to a Pool that hasn't been persisted.  Save the pool first." unless pool.persisted?
    file_node.bucket = pool.persistent_id # s3 bucket name
    file_node.content = file.read
    if file.respond_to?(:mime_type)
      file_node.mime_type = file.mime_type
    end
    file_node.content_type # Sets content_type field
    file_node.save!
    files << file_node
    update
    return file_node
  end

  # This list is persisted as an array of persistent_ids in associations["files"]
  # It's persisted as an array of ids rather than an association in database because order is relevant and multiple nodes might reference the same file.
  # DO NOT manipulate associations["files"] directly.  Those changes will not be persisted.
  def files
    if data['files'].nil?
      @files ||= []
    else
      @files ||= data['files'].map{|pid| Node.find_by_persistent_id(pid).extend(FileEntity)}
    end
  end

  def files=(new_files)
    if new_files.kind_of? Array
      @files = new_files
    elsif new_files.kind_of? Node
      @files = [new_files]
    else
      raise ArgumentError, "You can only pass an Array or a single Node into Node.files=.  You passed in a #{new_files.class} that looks like this:  #{new_files.inspect}"
    end
    update_file_ids
    return @files
  end

  # Tracks a list of associated files by id.
  # Note: Use .files accessor to set & get file associations.
  # DO NOT manipulate this array or the associations["files"] array directly.  Those changes will not be persisted.
  def file_ids
    ids = update_file_ids
    # this will be nil if no file associations have been set, so return an empty Array.
    if ids.nil?
      return []
    else
      return ids
    end
  end

  # Updates associations['files'] based on the current contents of @files attribute
  # If @files is empty, the associations will be left untouched.
  def update_file_ids
    # Don't set "files" key in associations hash unless there are files to associate.
    data['files'] = files.map{|file| file.persistent_id} unless files.empty?
  end

  private :file_ids, :update_file_ids

end
