module Api::V1::SwaggerDefs::ElasticsearchProxy
  extend ActiveSupport::Concern

  included do
    swagger_controller :data, "Interact with Pool Data"

    swagger_api :index do
      summary "Queries all Data in the Pool"
      # notes ""
      param :path, :id, :string, :required, "Pool ID"
      param :form, :body, :string, :optional, "Elasticsearch Query body"
      response :unauthorized
      response :not_acceptable, "The request you made is not acceptable"
      # response :requested_range_not_satisfiable
    end
  end
end
