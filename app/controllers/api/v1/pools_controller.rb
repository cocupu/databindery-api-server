class Api::V1::PoolsController < ApplicationController
  include Api::V1::SwaggerDefs::Pools
  before_filter :find_pool
  # load_resource :identity, :find_by => :short_name, :only=>[:index, :show, :edit, :fields]
  load_and_authorize_resource :only=>[:show, :edit]
  load_resource :pool, :id_param=>:pool_id, :find_by => :short_name, :through=>:identity, :only=>[:fields]

  def find_pool
    if /\A[-+]?\d+\z/ === params[:id]
      @pool = Pool.find(params[:id])
    elsif params[:id]
      @pool = Pool.find_by_short_name(params[:id])
    end
    if @pool
      @identity = @pool.owner
    end
  end

  def index
    ### This query finds all the pools belonging to @identity that can be seen by current_identity
    @pools = Pool.for_identity(current_identity)
    render :json=>@pools.map {|p| {short_name: p.short_name, name:p.name, description:p.description, identity:p.owner.short_name, url: api_v1_pool_path(p)}}
  end

  def show
    authorize! :show, @pool
    render :json=>@pool
  end

  def new
  end

  def edit
    authorize! :edit, @pool
  end

  def create
    authorize! :create, Pool
    # Make sure they own the currently set identity.
    identity = current_user.identities.find_by_short_name(params[:identity_id])
    raise CanCan::AccessDenied.new "You can't create for that identity" if identity.nil?
    @pool = identity.pools.build(pool_params)

    @pool.owner = identity
    @pool.save!
    respond_to do |format|
      format.json { render :json=>@pool}
      format.html {redirect_to identity_pool_path(identity_id:@identity.short_name, id:@pool.short_name) }
    end
  end

  def update
    raise CanCan::AccessDenied.new unless current_user
    # Make sure they own the currently set identity.
    identity = current_user.identities.where(:short_name=>params[:identity_id]).first!
    @pool = identity.pools.find_by_short_name(params[:id])
    authorize! :update, @pool
    if params[:update_index]
      update_index
    end

    # When content posted from JSON, this value is in params[:access_controls], not params[:pool][:access_controls]
    if params[:access_controls]
      access_controls = params[:access_controls]
    else
      access_controls = params[:pool][:access_controls]
    end

    unless access_controls.nil?
      @pool.access_controls = []
      access_controls.each do |ac|
        ident = Identity.where(short_name: ac[:identity]).first
        next if !ident or !['EDIT', 'READ'].include?(ac[:access]) ## TODO add error?
        @pool.access_controls.build identity: ident, access: ac[:access]
      end
    end
    @pool.update_attributes(pool_params)

    respond_to do |format|
      # format.html { redirect_to edit_identity_pool_path(@identity.short_name, @pool) }
      format.json { head :no_content }
    end
  end
  
  private

  def pool_params
    if params.has_key?(:pool)
      pool_params = params.require(:pool)
    else
      pool_params = params
    end
    pool_params.permit(:description, :name, :short_name)
  end

  # Update the solr index with the pool's head (current version of all nodes)
  def update_index
    failed_nodes = @pool.update_index
    flash[:notice] ||= []
    flash[:notice] << "Reindexed #{@pool.node_pids.count} nodes with #{failed_nodes.count} failures."
  end
end
