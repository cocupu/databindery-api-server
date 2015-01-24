class ApplicationController < ActionController::API
  include ActionController::MimeResponds
  include DeviseTokenAuth::Concerns::SetUserByToken
  include CanCan::ControllerAdditions  # Must explicitly include this because we're not inheriting from ActionController::Base

  rescue_from CanCan::AccessDenied do |exception|
      if login_credential_signed_in?
        logger.debug "permission denied #{exception.action} #{exception.subject}"
        json_body = Api::V1.generate_response_body(:forbidden)
        if exception.message
          json_body[:description] = exception.message unless exception.message == I18n.t('unauthorized.default')
        end
        render :json=>json_body, :status => :forbidden
      else
        logger.debug "Not logged in"
        json_body = Api::V1.generate_response_body(:unauthorized)
        json_body[:description] = exception.message if exception.message
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

  # Loads @pool using the id from params.  The id can be either the ID or the short_name of the pool
  # Options:
  # [:+id_param+]
  #   Find the pool using a param key other than :pool_id. For example:
  #
  #     load_pool :id_param => :my_id # will use find(params[:my_id])
  #    Or in a before_filter:
  #     before_filter -> { load_pool :id_param => :my_id }, :only=>[:show, :update, :fields]
  def load_pool(opts={})
    id_param = opts.fetch(:id_param, :pool_id)
    if /\A[-+]?\d+\z/ === params[id_param].to_s
      @pool = Pool.find(params[id_param])
    elsif params[id_param]
      @pool = Pool.find_by_short_name(params[id_param])
    end
    if @pool
      @identity = @pool.owner
    end
  end

end
