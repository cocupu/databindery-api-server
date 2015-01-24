class Pool < ActiveRecord::Base
  include ActiveModel::ForbiddenAttributesProtection
  include Bindery::Identifiable
  
  before_create :generate_uuid
  before_destroy :delete_bucket
  belongs_to :owner, class_name: "Identity"
  validates :owner, presence: true
  has_many :exhibits, :dependent => :destroy
  belongs_to :chosen_default_perspective, class_name: "Exhibit"
  has_many :nodes, :dependent => :destroy do
    def head
      pool_pids = map {|n| n.persistent_id}.uniq
      return pool_pids.map {|pid| Node.latest_version(pid)}
    end
  end
  # A more efficient way to load complete head state of the pool
  def nodes_head(args = {})
    return node_pids.map {|pid| Node.latest_version(pid)}
  end

  def node_pids
    ActiveRecord::Base.connection.execute("SELECT DISTINCT persistent_id FROM nodes WHERE pool_id = #{self.id}").values
  end

  has_many :models, :dependent => :destroy
  has_many :mapping_templates, :dependent => :destroy
  has_many :s3_connections, :dependent => :destroy
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

  def apply_solr_params_for_identity(identity, solr_params={}, user_params={})
    # Unless user has explicit read/edit access, apply filters based on audience memberships
    if access_controls.where(identity_id:identity.id).empty?
      filters = []
      audiences_for_identity(identity).each do |audience|
        filters.concat(audience.filters)
      end
      if filters.empty?
        SearchFilter.apply_solr_params_for_filters(default_filters, solr_params, user_params)
      else
        SearchFilter.apply_solr_params_for_filters(filters, solr_params, user_params)
      end
    end
    return solr_params, user_params
  end

  # This filters out everything by default!
  def default_filters
    return [SearchFilter.new(operator:"-", filter_type:"RESTRICT", field:Field.new(code:"*"), values:["*"])]
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
    [Field.canonical("model_name")] + self.models.map {|m| m.fields.where('type != ? OR type IS null',OrderedListAssociation)}.flatten.sort{|x, y| x.code <=> y.code}
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
    Bindery::Storage::S3
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
    if bucket.exists?
      bucket.clear!
      bucket.delete
    end
  end

  def update_index
    failed_nodes = []
    node_pids.each do |node_pid|
      n = Node.latest_version(node_pid)
      begin
        n.update_index
      rescue
        failed_nodes << n
      end
    end

    # flash[:notice] ||= []
    # flash[:notice] << "Reindexed #{pool_head.count} nodes with #{failed_nodes.count} failures."
    logger.info("Reindexed #{node_pids.count} nodes in Pool #{self.id} with #{failed_nodes.count} failures.")
  end

  # Serialize the pool and it's access_controls to a basic datastruture.
  def as_json(opts = nil)
    h = super
    h['identity'] = owner.id
    h['access_controls'] = access_controls.map {|ac| {'identity' => ac.identity.id, 'access' => ac.access  }}
    h
  end
end
