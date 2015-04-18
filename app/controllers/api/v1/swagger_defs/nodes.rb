module Api::V1::SwaggerDefs::Nodes
  extend ActiveSupport::Concern

  included do
    swagger_controller :nodes, "Node Management"

    swagger_api :index do
      summary "Queries all Nodes in the specified pool"
      notes "In the future, this will allow searching of all public nodes, but currently it's primarily a way for client code to find all of the nodes owned by the current user."
      param :path, :pool_id, :string, :required, "ID of the pool to search within"
      response :unauthorized
      response :forbidden
      response :unprocessable_entity, "The request you made could not be processed"
      # response :requested_range_not_satisfiable
    end

    swagger_api :create do
      summary "Creates a Node"
      param :path, :pool_id, :string, :required, "ID of the pool to create within"
      param :form, :name, :string, :required, "A name for the node"
      param :form, :label_field_id, :string, :optional, "ID of the field that is used as the 'label' or 'title' field.  This must be the id of a Field that is associated with this Node."
      param :form, :fields, :string, :optional, "Attributes for Fields that should be created/updated/associated with this node."
      param :form, :association_fields, :string, :optional, "Attributes for the subset of Fields that indicate associations between nodes.  You can also create these via the fields param"
      response :unauthorized, "Authentication required. You are not authenticated."
      # response :forbidden, "You do not have permission to perform this operation."
      response :not_acceptable
      response :not_found
    end

    swagger_api :update do
      summary "Updates a Node"
      param :path, :pool_id, :string, :required, "ID of the pool the node exists in"
      param :path, :id, :integer, :required, "Pool Id"
      param :form, :name, :string, :optional, "A name for the pool"
      param :form, :short_name, :string, :optional, "A short name for the pool. Must contain alphanumeric characters, dashes (-) and underscores (_) without spaces."
      param :form, :description, :string, :optional, "Description of the pool's content"
      response :success, "Success", :Node
      response :unauthorized
      response :not_acceptable
      response :not_found
    end

    swagger_api :show do
      summary "Fetches a single Node"
      param :path, :pool_id, :string, :required, "ID of the pool the node exists in"
      param :path, :id, :integer, :required, "Node ID"
      response :success, "Success", :Node
      response :unauthorized
      response :not_acceptable
      response :not_found
    end

    swagger_api :history do
      summary "Fetches the full history of changes to the node"
      param :path, :pool_id, :string, :required, "ID of the pool the node exists in"
      param :path, :id, :integer, :required, "Node Persistent ID"
      response :success, "Success", :Node
      response :unauthorized
      response :not_acceptable
      response :not_found
    end

    swagger_model :Node do
      description "An Identity object."
      property :id, :integer, :required, "Persistent ID of this node (and all other versions of the node)"
      property :node_version_id, :integer, :required, "Unique ID of this specific version of the node"
      property :model_id, :string, :optional, "ID of the Model that this Node conforms to"
      property :pool_id, :string, :optional, "ID of the Pool that this node is stored in"
      property :data, :string, :optional, "The (JSON) data for this node"
      property :modified_by, :string, :optional, "Identity of the person who created this specific version of the node (person who modified the node to the state represented by this node version)"
    end
  end
end