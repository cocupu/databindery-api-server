class Api::V1::FileEntitiesController < ApplicationController
  load_and_authorize_resource :class=>'Node', :find_by => :persistent_id, only: [:show]
  before_filter :load_pool
  load_and_authorize_resource :pool


  # Register the document in Data Bindery
  def create
    @target_node = Node.find_by_persistent_id(params[:target_node_id])
    # Only return the target node if current user can edit it.
    @target_node = nil unless can?(:edit, @target_node)
    @file_entity = FileEntity.register(@pool, file_entity_params)
    unless @target_node.nil?
      @target_node.files << @file_entity
      @target_node.save
    end
    render :json=>@file_entity
  end

  # Generate persistent_id and s3 key for the file to be uploaded & return that with encrypted S3 upload policy, signature, etc.
  def s3_upload_info
    prepare_pool_file_store_for_upload
    @file_entity = FileEntity.placeholder_for_upload(@pool, {})
    render :json => {
        key: @file_entity.storage_location_id,
        AWSAccessKeyId: AWS.config.access_key_id,
        acl: "private",
        success_action_status: "200",
        policy: s3_upload_policy_document,
        signature: s3_upload_signature,
        success_action_redirect: api_v1_pool_file_entities_path(@pool),
        uuid: @file_entity.persistent_id
    }
  end

  # just in case you need to do anything after the document gets uploaded to amazon.
  # but since we are sending our docs via a hidden iframe, we don't need to show the user a
  # thank-you page.
  #def s3_confirm
  #  head :ok
  #end

  def show
    redirect_to @file_entity.s3_url.to_s
  end

  private

  def file_entity_params
    if params[:file].nil?
      process_s3_direct_upload_params
      return params.permit(:binding, :url, {data: [:storage_location_id, :file_name, :file_size, :mime_type]})
    else
      # Move the file_name, etc into :data
      unless params.require(:file).permit(:file_name, :mime_type, :file_size, :storage_location_id, :bucket).empty?
        params[:file][:data] ||= {}
        params[:file][:data].merge!(params.require(:file).permit(:file_name, :mime_type, :file_size, :storage_location_id, :bucket, :mime_type))
        [:file_name, :mime_type, :file_size, :storage_location_id, :bucket].each {|k| params[:file].delete(k)}
      end

      # Whitelist regular file attributes
      permitted = params.permit(file:[:persistent_id, :binding]).tap do |whitelisted|
        if params[:file][:data]
          whitelisted[:file][:data] = params[:file][:data]
        end
        if params[:file][:associations]
          whitelisted[:file][:associations] = params[:file][:associations]
        end
      end
      return permitted[:file]
    end
  end

  # generate the policy document that amazon is expecting.
  def s3_upload_policy_document
    return @policy if @policy
    ret = {"expiration" => 5.minutes.from_now.utc.xmlschema,
           "conditions" =>  [
               {"bucket" =>  @pool.bucket_id},
               ["starts-with", "$key", @file_entity.storage_location_id],
               {"acl" => "private"},
               {"success_action_status" => "200"},
               ["content-length-range", 0, 1048576]
           ]
    }
    @policy = Base64.encode64(ret.to_json).gsub(/\n/,'')
  end

  # sign our request by Base64 encoding the policy document.
  def s3_upload_signature
    signature = Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha1'), AWS.config.secret_access_key, s3_upload_policy_document)).gsub("\n","")
  end

  def process_s3_direct_upload_params
    if params[:data].nil? && !params[:url].nil?
      params[:data] = params.slice(:storage_location_id, :file_name, :file_size, :mime_type)
      params[:data]["storage_location_id"] = params["filepath"] unless params["filepath"].nil?
      params[:data]["file_name"] = params["filename"] unless params["filename"].nil?
      params[:data]["file_size"] = params["filesize"] unless params["filesize"].nil?
      params[:data]["mime_type"] = params["filetype"] unless params["filetype"].nil?
    end
  end

  def prepare_pool_file_store_for_upload
    bucket = @pool.ensure_bucket_initialized
    @pool.default_file_store.ensure_cors_for_uploads(bucket.name)
  end
end
