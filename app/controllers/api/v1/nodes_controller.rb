class Api::V1::NodesController < ApplicationController
  include Blacklight::Controller
  include Blacklight::SolrHelper
  load_and_authorize_resource :except=>[:index, :search, :update, :create, :import, :find_or_create], :find_by => :persistent_id
  before_filter :load_pool
  load_and_authorize_resource :pool
  load_resource :model, through: :node, singleton: true, only: [:show]

  def index
    if params[:model_id]
      @model = Model.find(params[:model_id])
      authorize! :read, @model
      @nodes = @model.nodes.where("nodes.pool_id = ?", @pool)
    else
      @nodes = @pool.nodes
    end
    render json: @nodes.to_json
  end

  def search
    if params[:model_id]
      @model = Model.find(params[:model_id])
      authorize! :read, @model
    end

    # Constrain results to this pool
    fq = "pool:#{@pool.id}"
    fq += " AND model:#{@model.id}" if @model
    fq += " AND format:Node"

    ## TODO do we need to add query_fields for File entities?
    query_fields = @pool.models.map {|model| model.field_codes.map{ |key| Node.solr_name(key) } }.flatten.uniq
    (solr_response, @facet_fields) = get_search_results( params, {:qf=>(query_fields + ["pool"]).join(' '), :qt=>'search', :fq=>fq, :rows=>1000, 'facet.field' => ['name_si', 'model']})
    
    # puts "# of solr_docs: #{solr_response.docs.length}"
    # puts "solr_response: #{solr_response.docs}"
    @results = solr_response.docs.map{|d| serialize_node( Node.find_by_persistent_id(d['id']) ) }

    render json: @results
  end

  def show
    respond_to do |format|
      format.mp3 do
        if @node.model == Model.file_entity
          send_data @node.content, :type=>@node.mime_type, :disposition => 'inline'
        else
          render :file => "public/404", :status => :not_found, :layout=>nil
        end
      end
      format.ogg do
        if @node.model == Model.file_entity
          require 'open3'
          ## by default rails sets the encoding to UTF_8, this causes a UndefinedConversionError
          ## when dealing with binary data.
          Encoding.default_internal = nil
          ## run mpg321 reading from stdin, in quiet mode, encoding to wav
          ## take that stream and encode it with oggenc in quiet mode 
          ## read the output (stdout) and stream it to the web client
          stdin, stdout, wait_thr = Open3.popen2('mpg321 - -q -w -|oggenc - -Q')
          stdin.write @node.content
          stdin.close
          send_data stdout.read, :type=>'ogg', :disposition => 'inline'
          stdout.close
          Encoding.default_internal = Encoding::UTF_8 #Restore default expected by rails
        else
          render :file => "public/404", :status => :not_found, :layout=>nil
        end
      end
      format.json { render json: serialize_node(@node) }
      # format.html
    end
  end
  
  def create
    authorize! :create, Node
    @node = Node.new(node_params)
    @node.modified_by = @identity
    begin
      model = @pool.models.find(params[:node][:model_id])
    rescue ActiveRecord::RecordNotFound 
      #User didn't have access to the model they were trying to set.
      error_message = "Either a Model does not exist with id #{params[:node][:model_id]} or you are not allowed access to it.  This prevents you from creating a Node with that Model."
      render :json=>Api::V1.generate_response_body(:bad_request, errors:[error_message]), :status=>:bad_request
      return
    end
    @node.model = model
    @node.pool = @pool
    @node.save!
    render :json=>serialize_node(@node)
  end

  def import
    authorize! :create, Node
    model = @pool.models.find(params[:model_id])
    @import_results = Node.bulk_import_records(params[:data], @pool, model)
    render :json=>@import_results
  end
  
  # Uses advanced search request handler to find Nodes matching the request.
  # Currently only searches against attribute values.  Does not search against associations (though associations in the create request will be applied to the Node if created.)
  def find_or_create
    authorize! :create, Node
    begin
      model = @pool.models.find(params[:node][:model_id])
    rescue ActiveRecord::RecordNotFound
      #User didn't have access to the model they were trying to set.
      redirect_to new_identity_pool_node_path(@identity, @pool, :binding=>@node.binding)
      return
    end

    @node = Bindery::Curator.instance.find_or_create_node(node_params.merge(model:model,pool:@pool))

    render :json=>serialize_node(@node)
  end

  def update
    @node = Node.find_by_persistent_id(params[:id])
    authorize! :update, @node
    @node.attributes = node_params
    @node.modified_by = @identity
    new_version = @node.update
    render :json=>serialize_node(new_version)
  end
  
  def destroy
    node_name = @node.title
    @pool = @node.pool
    @node.destroy
    json_body = ::Api::V1.generate_response_body(:deleted,description:"Deleted node #{@node.id} (#{node_name}) from Pool #{@pool.id}.")
    render :json=>json_body
  end

  def attach_file
    @node = Node.find_by_persistent_id(params[:node_id])
    authorize! :attach_file, @node
    if @pool.default_file_store.nil?
      json_body = ::Api::V1.generate_response_body(:unprocessable_entity,error:"You must set up a file store before attaching a file")
      render :json=>json_body, :status=>:unprocessable_entity
      return
    end
    begin
      file_node = @node.attach_file(params[:file_name], params[:file])
    rescue Exception => e
      json_body = ::Api::V1.generate_response_body(:unprocessable_entity,errors:[e.message]) #backtrace:e.backtrace.inspect
      render :json=>json_body, :status=>:unprocessable_entity
      return
    end
    render :json=>serialize_node(file_node)
  end

  private

  # Whitelisted attributes for create/update
  def node_params
    if params.has_key?(:node)
      node_params = params.require(:node)
    else
      node_params = params
    end
    node_params.permit(:binding).tap do |whitelisted|
      if node_params[:data]
        whitelisted[:data] = node_params[:data]
      end
      if node_params[:associations]
        whitelisted[:associations] = node_params[:associations]
      end
    end
  end

  def serialize_node(n)
    return n.as_json.merge({url: api_v1_pool_node_path(n.pool, n), pool: n.pool.short_name, identity: n.pool.owner.short_name, binding: n.binding, model_id: n.model_id })
  end

  def blacklight_solr
    @solr ||=  RSolr.connect(blacklight_solr_config)
  end

  def blacklight_solr_config
    Blacklight.solr_config
  end
  
  def init_node_from_params
    begin
      model = @pool.models.find(params[:node][:model_id])
    rescue ActiveRecord::RecordNotFound 
      #User didn't have access to the model they were trying to set.
      redirect_to new_identity_pool_node_path(@identity, @pool, :binding=>@node.binding)
      return
    end
    @node = Node.new(node_params)
    @node.model = model
    @node.pool = @pool
  end

end
  
