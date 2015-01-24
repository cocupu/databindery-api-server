module Api::V1::SwaggerDefs::Models
  extend ActiveSupport::Concern

  included do
    swagger_controller :models, "Model Management"

    swagger_api :index do
      summary "Fetches all Models belonging to the current user"
      notes "In the future, this will allow searching of all public models, but currently it's primarily a way for client code to find all of the models owned by the current user."
      param :query, :pool_id, :string, :optional, "ID or short_name of the pool to search within"
      response :unauthorized
      response :forbidden
      response :unprocessable_entity, "The request you made could not be processed"
      # response :requested_range_not_satisfiable
    end

    swagger_api :create do
      summary "Creates a Model"
      param :form, :name, :string, :required, "A name for the model"
      param :form, :label_field_id, :string, :optional, "ID of the field that is used as the 'label' or 'title' field.  This must be the id of a Field that is associated with this Model."
      param :form, :fields, :string, :optional, "Attributes for Fields that should be created/updated/associated with this model."
      param :form, :association_fields, :string, :optional, "Attributes for the subset of Fields that indicate associations between nodes.  You can also create these via the fields param"
      response :unauthorized, "Authentication required. You are not authenticated."
      # response :forbidden, "You do not have permission to perform this operation."
      response :not_acceptable
      response :not_found
    end

    swagger_api :update do
      summary "Updates a Pool"
      param :path, :id, :integer, :required, "Pool Id"
      param :form, :name, :string, :optional, "A name for the pool"
      param :form, :short_name, :string, :optional, "A short name for the pool. Must contain alphanumeric characters, dashes (-) and underscores (_) without spaces."
      param :form, :description, :string, :optional, "Description of the pool's content"
      response :success, "Success", :Model
      response :unauthorized
      response :not_acceptable
      response :not_found
    end

    swagger_api :show do
      summary "Fetches a single Model"
      param :path, :id, :integer, :optional, "Model ID"
      response :success, "Success", :Model
      response :unauthorized
      response :not_acceptable
      response :not_found
    end

    swagger_model :Model do
      description "An Identity object."
      property :id, :integer, :required, "Identity Id"
      property :name, :string, :optional, "Name"
      property :label_field_id, :string, :optional, "ID of the field that is used as the 'label' or 'title' field"
      property :fields, :array, :optional, "Fields used by this Model"
      property :association_fields, :array, :optional, "Convenience method providing the subset of Fields that indicate associations between nodes."
      property :url, :string, :optional, "URL for this Model"
    end
  end
end