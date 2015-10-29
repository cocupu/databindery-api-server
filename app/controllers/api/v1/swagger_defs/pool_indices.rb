module Api::V1::SwaggerDefs::PoolIndices
  extend ActiveSupport::Concern

  included do
    swagger_controller :indices, "Index Management"

    swagger_api :index do
      summary "Lists indices belonging to the Pool"
      # notes ""
      param :path, :pool_id, :string, :required, "ID of the pool to search within"
      response :unauthorized
      response :forbidden
      response :not_acceptable, "The request you made is not acceptable"
      # response :requested_range_not_satisfiable
    end

    swagger_api :create do
      summary "Creates a new elasticsearch Index for the pool and and (optionally) writes the pool's models into the index as mappings"
      param :path, :pool_id, :string, :required, "ID of the pool the index will belong to"
      param :form, :source, :string, :optional, "Source to index data from (defaults to nil - don't add conent to the index)"
      param :form, :alias, :boolean, :optional, "Whether to make this new index the 'live' index pointed to by the pool's alias"
      param :form, 'source[dat][from]', :string, :optional, "start point (commit reference) for indexing only content that has changed within a certian time range"
      param :form, 'source[dat][to]', :string, :optional, "end point (commit reference) for indexing only content that has changed within a certian time range"
      param :form, :write_models, :boolean, :optional, "Whether to write the pool's models to the index as elasticsearch mappings. (Default: true) This is mainly useful if you want to allow the index to auto-detect data types."
      response :success, "Success", :Index
      response :unauthorized
      response :not_acceptable
      response :not_found
    end

    swagger_api :update do
      summary "Updates the Index (aka. adds data/documents to the index), often pulling content from dat"
      param :path, :pool_id, :string, :required, "ID of the pool the index belongs to"
      param :path, :id, :integer, :required, "Index Name"
      param :form, :source, :String, :optional, "the source to index from (defaults to :dat). Alternatively provide {dat: {from: 'commitHash', to: 'commitHash'}"
      response :success, "Success", :Index
      response :unauthorized
      response :not_acceptable
      response :not_found
    end

    swagger_api :show do
      summary "Fetches the info about a single Index"
      param :path, :pool_id, :string, :required, "ID of the pool the index belongs to"
      param :path, :id, :integer, :required, "Index Name"
      response :success, "Success", :Index
      response :unauthorized
      response :not_acceptable
      response :not_found
    end

    swagger_api :destroy do
      summary "Deletes an Index"
      param :path, :pool_id, :string, :required, "ID of the pool the index belongs to"
      param :path, :id, :integer, :required, "Index Name"
      response :success, "Success"
      response :unauthorized
      response :not_acceptable
      response :not_found
    end

    swagger_model :Index do
      description "An elasticsearch index.  You can have many elasticsearch indexes for a single pool, but only one 'live' index that will be queried by default when you run a search agains the pool's data"
      property :index_name, :string, :required, "Index Name"
    end

  end
end
