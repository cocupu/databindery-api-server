module Api::V1::SwaggerDefs::Pools
  extend ActiveSupport::Concern

  included do
    swagger_controller :pools, "Pool Management"

    swagger_api :index do
      summary "Queries all Pools visible to the current user"
      # notes ""
      param :query, :q, :string, :optional, "Query string"
      response :unauthorized
      response :not_acceptable, "The request you made is not acceptable"
      # response :requested_range_not_satisfiable
    end

    swagger_api :create do
      summary "Creates a Pool"
      param :form, :name, :string, :required, "A name for the pool"
      param :form, :short_name, :string, :required, "A short name for the pool. Must contain alphanumeric characters, dashes (-) and underscores (_) without spaces."
      param :form, :description, :string, :optional, "Description of the pool's content"
      response :success, "Success", :Pool
      response :unauthorized
      response :not_acceptable
      response :not_found
    end

    swagger_api :update do
      summary "Updates a Pool"
      param :path, :id, :integer, :required, "Pool Id"
      param :form, :name, :string, :optional, "A name for the pool"
      param :form, :short_name, :string, :optional, "A short name for the pool. Must contain alphanumeric characters, dashes (-) and underscores (_) without spaces."
      param :form, :description, :string, :optional, "Description of the pool's content"
      response :success, "Success", :Pool
      response :unauthorized
      response :not_acceptable
      response :not_found
    end

    swagger_api :show do
      summary "Fetches the info about a single Pool"
      param :path, :id, :integer, :required, "Pool Id"
      response :success, "Success", :Pool
      response :unauthorized
      response :not_acceptable
      response :not_found
    end

    swagger_api :destroy do
      summary "Deletes a Pool"
      param :path, :id, :integer, :required, "Pool Id"
      response :success, "Success"
      response :unauthorized
      response :not_acceptable
      response :not_found
    end

    swagger_model :Pool do
      description "An Identity object."
      property :id, :integer, :required, "Pool Id"
      property :name, :string, :optional, "Name"
      property :short_name, :string, :optional, "Short Name. Must contain alphanumeric characters, dashes (-) and underscores (_) without spaces."
      property :description, :string, :optional, "Description of the Pool."
      property :identity, :integer, "ID of the identity that owns the pool"
      property :access_conrols, :array, "Array of AccessControls that are enforced on this pool."
    end
  end
end
