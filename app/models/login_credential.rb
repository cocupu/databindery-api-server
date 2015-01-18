class LoginCredential < ActiveRecord::Base
  include DeviseTokenAuth::Concerns::User

  has_many :identities, :dependent => :destroy

  accepts_nested_attributes_for :identities

  after_initialize :create_identity
  before_validation :remove_blank_identities

  def remove_blank_identities
    # identities.reject{|ident| ident.short_name.nil? }
  end

  def create_identity
    identities.build if identities.empty?
  end
end
