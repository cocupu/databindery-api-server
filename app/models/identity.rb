class Identity < ActiveRecord::Base
  include ActiveModel::ForbiddenAttributesProtection

  belongs_to :login_credential
  has_many :pools, :foreign_key=>'owner_id', :dependent => :destroy
  has_many :exhibits, :through=>:pools#, :foreign_key=>'owner_id', :dependent => :destroy
  has_many :models, :foreign_key=>'identity_id', :dependent => :destroy
  has_many :mapping_templates, :dependent => :destroy
  has_many :google_accounts, :foreign_key=>'owner_id', :dependent => :destroy
  has_many :chattels, :foreign_key=>'owner_id', :dependent => :destroy
  has_many :changes, :class_name => "Node", :foreign_key=>"modified_by_id"
  has_and_belongs_to_many :audiences
  validates :short_name, :presence=>true, :uniqueness=>true, :format=>{:with=>/\A\w+[\w-]+\z/,
    :message => "may only contain alphanumeric characters or dashes and cannot begin with a dash" }

  def short_name=(val)
    write_attribute(:short_name, val.downcase)
  end

  def to_param
    short_name
  end

  ANONYMOUS_VISITOR_CODE = "anonymous"
  REGISTERED__VISITOR_CODE = "registered"

  def self.anonymous_visitor
    Identity.where(short_name: ANONYMOUS_VISITOR_CODE).first_or_create!(short_name: ANONYMOUS_VISITOR_CODE)
  end

  def self.registered
    Identity.where(short_name: REGISTERED__VISITOR_CODE).first_or_create!(short_name: REGISTERED__VISITOR_CODE)
  end

end
