class Api::V1::PoolIndicesController < ApplicationController
  include Api::V1::SwaggerDefs::PoolIndices

  before_filter :load_pool
  before_filter :require_pool_read_access, only: [:index, :show]
  before_filter :require_pool_edit_access, only: [:create, :update, :destroy]

  def index
    aliases = @pool.__elasticsearch__.get_aliases(scope: :all)
    render json: aliases.keys
  end

  def create
    created_index_name = @pool.__elasticsearch__.create_index(index_name: index_name_from_params)
    if params[:source]
      @pool.update_index(index_name: created_index_name, source: params[:source])
    end
    @pool.models.each {|model| model.__elasticsearch__.save(index_name: created_index_name) } unless params[:write_models] == false
    if params[:alias]
      @pool.__elasticsearch__.set_alias(created_index_name)
    end
    render :json=>{}
  end

  def show
    index_name = index_name_from_params
    begin
      @pool.__elasticsearch__.require_index_to_be_in_pool!(index_name) unless index_name == @pool.to_param
    rescue ArgumentError => e
      render json: Api::V1.generate_response_body(:unprocessable_entity, description: e.message), :status => :unprocessable_entity
      return
    end
    json = @pool.__elasticsearch__.get_index(index_name)
    render :json=>json
  end

  def update
    begin
      @pool.update_index(index_name: index_name_from_params, source: params[:source])
    rescue ArgumentError => e
      render json: Api::V1.generate_response_body(:unprocessable_entity, description: e.message), :status => :unprocessable_entity
      return
    end

    if params[:alias]
      @pool.__elasticsearch__.set_alias(index_name_from_params)
    end
    render json: Api::V1.generate_response_body(:success)
  end

  def destroy
    @pool.__elasticsearch__.delete_index(index_name_from_params)
    render json: Api::V1.generate_response_body(:deleted)
  end

  private

  def index_name_from_params
    if params[:id] == 'live'
      if params[:index_name]
        params[:alias] ||= 'live'
        params[:index_name]
      else
        @pool.to_param
      end
    else
      params[:id]
    end
  end

end
