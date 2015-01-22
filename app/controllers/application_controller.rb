class ApplicationController < ActionController::API
  include ActionController::MimeResponds
  include DeviseTokenAuth::Concerns::SetUserByToken
  include CanCan::ControllerAdditions  # Must explicitly include this because we're not inheriting from ActionController::Base

  rescue_from CanCan::AccessDenied do |exception|
      if login_credential_signed_in?
        logger.debug "permission denied #{exception.action} #{exception.subject}"
        json_body = Api::V1.default_responses[:forbidden]
        json_body[:description] = exception.message if exception.message
        render :json=>json_body, :status => :forbidden
      else
        logger.debug "Not logged in"
        json_body = Api::V1.default_responses[:unauthorized]
        render :json=>json_body, :status => :unauthorized
      end
  end

  rescue_from ActiveRecord::RecordNotFound do |exception|
    json_body = Api::V1.default_responses[:not_found]
    render :json=>json_body, :status => :not_found
  end

  def current_ability
    @current_ability ||= Ability.new(current_identity)
  end

  def current_identity
    current_login_credential.identities.first if current_user
  end

  # Alias current_user to current_login_credential
  def current_user
    current_login_credential
  end

end
