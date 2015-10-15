class Pool < ActiveRecord::Base
  include ActiveModel::ForbiddenAttributesProtection
  include Bindery::Identifiable
  include Bindery::Persistence::ElasticSearch::Pool

  before_create :generate_uuid
  before_destroy :delete_bucket
  belongs_to :owner, class_name: "Identity"
  validates :owner, presence: true
  has_many :exhibits, :dependent => :destroy
  belongs_to :chosen_default_perspective, class_name: "Exhibit"

  has_many :models, :dependent => :destroy
  has_many :mapping_templates, :dependent => :destroy
  has_many :s3_connections, :dependent => :destroy, table_name:"s3_connections", class_name:"Bindery::Persistence::AWS::S3::Connection"
  has_many :access_controls, :dependent => :destroy
  has_many :audience_categories
  accepts_nested_attributes_for :access_controls

  validates :short_name, :format=>{:with => /\A[\w-]+\Z/}, :uniqueness => true
  
  attr :generated_default_perspective

  def self.for_identity(identity)
    # Cancan 1.6.8 was producing incorrect query, for accessible_by so,
    # lets' write something custom:
    # Must call unique or the owner will get multiple rows
    Pool.joins("LEFT OUTER JOIN access_controls ON access_controls.pool_id = pools.id").where("(owner_id = ?) OR access_controls.identity_id = ? ", identity.id, identity.id).uniq
  end

  def audiences_for_identity(identity)
    audiences = []
    audience_categories.each {|ac| audiences.concat ac.audiences_for_identity(identity) }
    audiences
  end
  
  def perspectives
    exhibits.unshift(generated_default_perspective)
  end
  
  def default_perspective
    if chosen_default_perspective.nil?
      generated_default_perspective
    else
      chosen_default_perspective  
    end
  end
  
  def generated_default_perspective
    unless @generated_default_perspective
      if all_fields.count < 36
        @generated_default_perspective = Exhibit.new(pool_id:self.id, index_fields: all_fields, facets: all_fields, title: "All Content, All fields")
      else
        limited_fields = all_fields[0..29]
        @generated_default_perspective = Exhibit.new(pool_id:self.id, index_fields: limited_fields, facets: limited_fields, title: "All Content, First 30 fields")
      end
    end

    return @generated_default_perspective
  end


  
  def short_name=(name)
    write_attribute :short_name, name.downcase
  end
  
  #
  # Serialization
  #
  def to_param
    id.to_s
  end

  def all_fields
    [Field.canonical("model_name")] + models_including_file_entity.map {|m| m.fields.where('type != ? OR type IS null',OrderedListAssociation)}.flatten.sort{|x, y| x.code <=> y.code}
  end
  
  # Returns all the associations from all Models in this Pool
  # Note: Use this sparingly, since it triggers a pretty heavy database hit.
  def all_associations(opts={})
    associations = self.models.map {|m| m.association_fields}.flatten
    if opts[:unique]
      unique_codes = associations.map {|a| a[:code] }.uniq
      unique_associations = []
      associations.each do |a|
        if unique_codes.include?(a[:code])
          unique_associations << a
          unique_codes.delete(a[:code])
        end
      end
      return unique_associations
    else
      return associations
    end
  end

  def file_store_type
    Bindery::Persistence::AWS::S3
  end

  def default_file_store
    # s3_connections.first
    file_store_type.default_connection
  end
  
  def default_bucket_id
    self.persistent_id
  end

  def bucket_id
    default_bucket_id
  end
  
  def bucket
    default_file_store.bucket(bucket_id)
  end
  
  def ensure_bucket_initialized
    generate_uuid
    default_file_store.ensure_bucket_initialized(default_bucket_id)
  end

  def delete_bucket
    begin
      if bucket.exists?
        bucket.clear!
        bucket.delete
      end
    rescue SocketError => e
      logger.warn("Could not delete bucket associated with Pool #{id}.  Looks like the connection to AWS failed? #{e.message}")
    end
  end

  # Serialize the pool and it's access_controls to a basic datastruture.
  def as_json(opts = nil)
    h = super
    h['identity'] = owner.id
    h['access_controls'] = access_controls.map {|ac| {'identity' => ac.identity.id, 'access' => ac.access  }}
    h
  end

  private

  def models_including_file_entity
    models + [Model.file_entity]
  end
end
