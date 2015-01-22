module Api::V1::SwaggerDefs::Identities
  extend ActiveSupport::Concern

  included do
    swagger_controller :identities, "Identity Management"

    swagger_api :index do
      summary "Fetches all Identities belonging to the current user"
      notes "In the future, this will allow searching of all public identities, but currently it's primarily a way for client code to find all of the identities owned by the current user."
      param :query, :email, :string, :optional, "Email address"
      response :unauthorized
      response :not_acceptable, "The request you made is not acceptable"
      # response :requested_range_not_satisfiable
    end

    swagger_api :show do
      summary "Fetches a single Identity"
      param :path, :id, :integer, :optional, "Identity Id"
      response :success, "Success", :Identity
      response :unauthorized
      response :not_acceptable
      response :not_found
    end

    swagger_model :Identity do
      description "An Identity object."
      property :id, :integer, :required, "Identity Id"
      property :name, :string, :optional, "Name"
      property :short_name, :string, :optional, "Short Name"
    end
  end
end