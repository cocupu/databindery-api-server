module Api::V1::SwaggerDefs::Data
  extend ActiveSupport::Concern

  included do
    swagger_controller :data, "Interact with Pool Data"

    swagger_api :index do
      summary "Queries all Data in the Pool"
      # notes ""
      param :path, :pool_id, :string, :required, "Pool ID"
      param :query, :q, :string, :optional, "Query string"
      param :query, 'f', :string, :optional, "Facet constraints using field codes"
      param :query, 'f[model_name][]', :string, :optional, "Constrains on model name facet"
      param :query, :facet_fields, :string, :optional, "Facet constraints using field ids"
      param :query, :sort_fields, :string, :optional, "Sort constraints using field ids"
      param :query, :rows, :string, :optional, "(pagination) number of rows/nodes to return in the response"
      param :query, :page, :string, :optional, "(pagination) page number"
      param :query, :perspective, :string, :optional, "Perspective to use when querying (specifies saved filters, facets, sorting, etc)"
      param :query, :nodesOnly, :boolean, :optional, "Only return node data.  Don't return query or facet info."
      param :query, :model_id, :string, :optional, "Only return data for nodes with this Model"

      response :unauthorized
      response :not_acceptable, "The request you made is not acceptable"
      # response :requested_range_not_satisfiable
    end

    swagger_api :overview do
      summary "Provides a pool overview with models, perspectives and aggregations/facets"
      # notes ""
      param :path, :pool_id, :string, :required, "Pool ID"

      response :unauthorized
      response :not_acceptable, "The request you made is not acceptable"
      # response :requested_range_not_satisfiable
    end

  end
end
