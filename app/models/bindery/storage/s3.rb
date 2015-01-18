module Bindery::Storage::S3
  def self.default_connection
    @conn ||= S3Connection.new(:access_key_id => AWS.config.access_key_id,
                            :secret_access_key => AWS.config.secret_access_key)
  end
  
  def self.key_from_filepath(filepath, options)
    key = CGI::unescape(filepath)
    if options.has_key?(:bucket)
      key.gsub!(options[:bucket], "")
    end
    # Shop off all preceding slashes
    key.gsub!(/^[\/]*/, "")
    return key
  end

  def self.generate_storage_location_id(file_entity)
    generated_id = file_entity.persistent_id + "_" + Time.now.strftime('%Y%m%dT%H%M%S%Z')
    if file_entity.file_name
      generated_id = [generated_id, file_entity.file_name].join("_")
    end
    return generated_id
  end

  def self.binding_url_from_node_info(file_entity)
    "https://s3.amazonaws.com/#{file_entity.bucket}/#{file_entity.storage_location_id}"
  end
end
