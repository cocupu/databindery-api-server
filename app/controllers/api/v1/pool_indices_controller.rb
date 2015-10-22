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
    render :json=>{}
  end

  def show
    render :json=>{}
  end

  def update
    if params[:source].nil? || params[:source] == 'dat'
      @pool.dat.index(index_name: index_name)
      puts "indexed into index named #{index_name}"
    elsif params[:source].kind_of?(Hash)
      dat_params = params[:source].fetch(:dat, {to: nil, from: nil})
      @pool.dat.index(index_name: index_name, from: dat_params[:from], to: dat_params[:to])
    end
    render json: Api::V1.generate_response_body(:success)
  end

  def destroy
    @pool.__elasticsearch__.delete_index(index_name)
    render json: Api::V1.generate_response_body(:deleted)
  end

  private

  def index_name
    if params[:id] == 'live'
      @pool.to_param
    else
      params[:id]
    end
  end

end
