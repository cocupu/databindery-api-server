class Node < ActiveRecord::Base
  include ActiveModel::ForbiddenAttributesProtection

  ## Most of the Action is in the Bindery::Node module and its submodules
  include Bindery::Node

  before_create :generate_uuid
  belongs_to :model
  belongs_to :pool
  belongs_to :parent, class_name: "Node"
  belongs_to :spawned_from_datum, class_name: "SpreadsheetRow"
  belongs_to :modified_by, class_name: "Identity"
  validates :model, presence: true
  validates :pool, presence: true

  serialize :data, Hash

  ## Id is our version, so this ensures that find_by_persistent_id always returns the most recent version
  default_scope { order('id desc') }
end
