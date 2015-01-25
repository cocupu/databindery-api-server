class Api::V1::MappingTemplatesController < ApplicationController
  before_filter :load_pool
  load_and_authorize_resource :pool
  load_and_authorize_resource :except=>[:create]


  def create
    authorize! :create, MappingTemplate
    identity = current_user.identities.find_by_short_name(params[:identity_id])
    raise CanCan::AccessDenied.new "You can't create for that identity" if identity.nil?
    @mapping_template = MappingTemplate.new(owner: identity, pool: @pool)
    begin
      @mapping_template.attributes = mapping_template_params
    rescue ActiveRecord::RecordInvalid => e
      ## Model was invalid
      render :json=>Api::V1.generate_response_body(:bad_request, errors:e.record.errors.full_messages), :status=>:bad_request
      return
    end
    @mapping_template.save!

    render json: @mapping_template
  end

  def update
    begin
      @mapping_template.attributes = mapping_template_params
    rescue ActiveRecord::RecordInvalid => e
      ## Model was invalid
      flash[:alert] = e.record.errors.full_messages.join("\n")
      render :action=>'new'
      return
    end
    @mapping_template.save!
    render json: @mapping_template
  end

  def show
    render json: @mapping_template
  end

  private

  def mapping_template_params
    params.require(:mapping_template).permit(:row_start,:pool_id).tap do |whitelisted|
      # if simplified json was submitted, rearrange it to work with @mapping_template.attributes=, which expects multiple model mappings
      if params[:mapping_template][:model_mappings_attributes].nil? && params[:mapping_template][:model_mappings]
        model_mapping = params[:mapping_template][:model_mappings][0]
        model_mapping[:field_mappings_attributes] = {}
        model_mapping[:field_mappings].each_with_index do |field_mapping, index|
          model_mapping[:field_mappings_attributes][index] = field_mapping
        end
        whitelisted[:model_mappings_attributes] = {"0"=>model_mapping}
      else
        #remove template fields
        params[:mapping_template][:model_mappings_attributes].each do |key, mma|
          mma['field_mappings_attributes'].delete('new_field_mappings')
        end
        # whitelist model_mappings_attributes
        if params[:mapping_template][:model_mappings_attributes]
          whitelisted[:model_mappings_attributes] = params[:mapping_template][:model_mappings_attributes]
        end
      end
    end
  end

end
