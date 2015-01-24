module Api
  module V1
class ModelsController < ApplicationController
  include Api::V1::SwaggerDefs::Models
  skip_before_filter :verify_authenticity_token, :if => Proc.new { |c| c.request.format == 'application/json' && c.request.params.include?(:auth_token) }

  before_filter :load_pool
  load_and_authorize_resource :pool, :only=>[:create, :index]
  load_and_authorize_resource :only=>[:show, :new, :edit, :destroy]

  def index
    #@models = Model.for_identity_and_pool(current_identity, @pool)
    if can?(:edit, @pool)
      @models = @pool.models + [Model.file_entity]
    end
    respond_to do |format|
      format.html {}
      format.json do
        render :json=>@models.map { |m| serialize_model(m) }
      end
    end
  end 

  def show
    respond_to do |format|
      format.json { render :json=>serialize_model(@model)}
    end
  end

  def create
    authorize! :create, Model
    @model = Model.new(model_params)
    begin
      identity = current_user.identities.find(params[:identity_id])
    rescue ActiveRecord::RecordNotFound
      raise CanCan::AccessDenied.new "You can't create for that identity"
    end

    @model.owner = identity
    @model.pool = @pool 
    if @model.save
      render :json=>serialize_model(@model)
    else
      render :json=>Api::V1.generate_response_body(:bad_request, errors:@model.errors.full_messages), :status=>:bad_request
    end
  end

  def update
    @model = Model.find(params[:id])
    authorize! :update, @model
    if @model.update_attributes(model_params)
      render :json=>serialize_model(@model)
    else
      render :json=>Api::V1.generate_response_body(:bad_request, errors:@model.errors.full_messages), :status=>:bad_request
    end
  end
  
  def destroy
    @model = Model.find(params[:id])
    @pool = @model.pool
    model_name = @model.name
    @model.destroy
    json_body = ::Api::V1.generate_response_body(:deleted,description:"Deleted model #{@model.id} (#{model_name}).")
    render :json=>json_body
  end

  private

  def serialize_model(m)
    json = {id: m.id, url: api_v1_model_path(m), association_fields: m.association_fields, fields: m.fields, name: m.name, label_field_id: m.label_field_id.to_s, allow_file_bindings: m.allow_file_bindings }
    json.merge!(pool: m.pool.short_name, identity: m.pool.owner.short_name) if m.pool
    json
  end

  # Whitelisted attributes for create/update
  def model_params
    if params.has_key?(:model)
      model_params = params.require(:model)
    else
      model_params = params
    end
    rename_json_fields_to_fields_attributes(model_params)
    rename_json_associations_to_associations_attributes(model_params)
    convert_label_field_code_to_id(model_params)
    model_params.permit(:name, :label_field_id, :allow_file_bindings, fields_attributes: [:id, :_destroy, :name, :type, :code, :uri, :references, :multivalue], association_fields_attributes: [:id, :_destroy, :name, :type, :code, :uri, :references, :multivalue])
  end

  # If label_field_id is set to a field code instead of a field id, replaces it with the id
  def convert_label_field_code_to_id(model_params)
    if model_params[:label_field_id]
      unless Field.exists?(model_params[:label_field_id])
        existing_field_with_matching_code = @model.fields.select {|f| f.code == model_params[:label_field_id]}.first
        if existing_field_with_matching_code
          field_with_matching_code = existing_field_with_matching_code
        else
          params_for_new_field = model_params.fetch(:fields_attributes, []).select {|f| f[:code] == model_params[:label_field_id]}.first
          if params_for_new_field
            params_for_new_field = params_for_new_field.permit([:name, :type, :code, :uri, :references, :multivalue])
            field_with_matching_code = Field.create(params_for_new_field)
            model_params[:fields_attributes].delete(params_for_new_field)
            model_params[:fields_attributes] << {id:field_with_matching_code.id}
          end
        end
        if field_with_matching_code
          field_with_matching_code.save unless field_with_matching_code.id
          model_params[:label_field_id] = field_with_matching_code.id
        end
      end
    end
  end

  # json objects list the filters as :filters, not :filters_attributes
  # this renames those submitted params so that they will be applied properly by update_attributes
  def rename_json_fields_to_fields_attributes(target_hash)
    # Grab the fields params out of the full submitted params hash
    if params["fields"]
      to_move = params["fields"]
    elsif params["model"]["fields"]
      to_move = params["model"]["fields"]
    end
    # Write the filters params into the target_hash as filters_attributes
    if to_move && target_hash["fields_attributes"].nil?
      target_hash["fields_attributes"] = to_move
    end
  end

  def rename_json_associations_to_associations_attributes(target_hash)
    # Grab the fields params out of the full submitted params hash
    if params["association_fields"]
      to_move = params["association_fields"]
    elsif params.has_key?(:model) && params["model"]["association_fields"]
      to_move = params["model"]["association_fields"]
    end
    # Write the filters params into the target_hash as filters_attributes
    if to_move && target_hash["association_fields_attributes"].nil?
      target_hash["association_fields_attributes"] = to_move
    end
  end
end
  end
end

