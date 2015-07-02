class Api::V1::AudiencesController < ApplicationController
  #load_resource :identity, :find_by => :short_name, :only=>[:index, :create]
  #load_and_authorize_resource :pool, :find_by => :short_name, :through=>:identity, :only=>[:index, :create]
  load_and_authorize_resource :audience_category, :only=>[:index, :create]
  load_and_authorize_resource :only=>[:show, :edit, :update]

  def index
    @audiences = @audience_category.audiences
    render :json=> @audiences.map {|audience| serialize_audience(audience) }
  end

  def show
    render :json=>serialize_audience(@audience)
  end

  def create
    @audience = @audience_category.audiences.build(audience_params)
    @audience.save
    render :json=>serialize_audience(@audience)
  end

  def update
    @audience.update_attributes(audience_params)
    render :json=>serialize_audience(@audience)
  end

  private

  def audience_params
    if params.has_key?(:audience)
      audience_params = params.require(:audience)
    else
      audience_params = params
    end
    rename_json_filters_to_filters_attributes(audience_params)
    audience_params.permit(:description, :name, {member_ids:[]}, filters_attributes: [:id, :_destroy, :field_name, :operator, {values:[]}, :association_code, :filter_type])
  end

  # json objects list the filters as :filters, not :filters_attributes
  # this renames those submitted params so that they will be applied properly by update_attributes
  def rename_json_filters_to_filters_attributes(target_hash)
    # Grab the filters params out of the full submitted params hash
    if params["filters"]
      to_move = params["filters"]
    elsif params["audience"] && params["audience"]["filters"]
      to_move = params["audience"]["filters"]
    end
    # Write the filters params into the target_hash as filters_attributes
    if to_move && target_hash["filters_attributes"].nil?
      target_hash["filters_attributes"] = to_move
    end
  end

  def serialize_audience(audience)
    audience.as_json.merge({pool_name:params[:pool_id], identity_name:params[:identity_id]})
  end


end
