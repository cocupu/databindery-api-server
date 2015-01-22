class Api::V1::IdentitiesController < ApplicationController
  include Api::V1::SwaggerDefs::Identities

  def index
    if params[:email]
      login_credential = LoginCredential.find_by_email(params[:email])
      @identities = Identity.where(:login_credential_id => login_credential.id)
    elsif params[:q]
      q = params[:q]
      capitalized = q.split.map(&:capitalize).join(' ')
      @identities = Identity.where("name LIKE :prefix OR name LIKE :capitalized OR short_name LIKE :prefix OR short_name LIKE :capitalized", prefix: "%#{q}%", capitalized:"%#{capitalized}%").limit(25)
    else
      if current_login_credential
        @identities = Identity.where(:login_credential_id => current_login_credential.id)
      else
        @identities = []
      end
    end
    render :json=> @identities.map {|i| serialize_identity(i) }
  end

  def show
    if @identity.nil? && params[:id].to_i.to_s == params[:id]
      @identity = Identity.find(params[:id])
    else
      @identity = Identity.find_by_short_name(params[:id])
    end
    render :json=>serialize_identity(@identity)
  end

  private
  def serialize_identity(identity)
    identity.as_json.reject {|k,v| k=="login_credential_id"}.merge({url: api_v1_identity_path(identity)})
  end
end
