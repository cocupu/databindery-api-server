class Model < ActiveRecord::Base
  FILE_ENTITY_CODE = 'FILE'
  include ActiveModel::ForbiddenAttributesProtection
  include Bindery::Persistence::ElasticSearch::Model

  has_many :node
  belongs_to :label_field, class_name:Field

  # NOTE: association_fields are a subset of fields.  You can create/modify fields via either .fields or .association_fields methods.
  has_and_belongs_to_many :fields
  accepts_nested_attributes_for :fields, allow_destroy: true
  has_and_belongs_to_many :association_fields, -> {where type:"OrderedListAssociation"}, class_name:"OrderedListAssociation", join_table:"fields_models", foreign_key: "model_id", association_foreign_key:"field_id"
  accepts_nested_attributes_for :association_fields, allow_destroy: true

  belongs_to :pool
  validates :pool, presence: true, :unless=>:code

  belongs_to :owner, class_name: "Identity", :foreign_key => 'identity_id'
  validates :owner, presence: true, :unless=>:code

  validates :label_field, :inclusion => {:in=> lambda {|model|  model.fields }, :message=>"must be one of the fields in this model"}, :if=>Proc.new { |a| a.label_field }

  validates :name, :presence=>true

  after_initialize :init

  #TODO add a fk on node.model_id
  has_many :nodes, :dependent => :destroy do
    def head
      model_pids = map {|n| n.persistent_id}.uniq
      return model_pids.map {|pid| Node.latest_version(pid)}
    end
  end
  # A more efficient way to load complete head state of all nodes using this model.
  # option to pass :pool argument to explicitly constrain to a specific pool
  # @example model.nodes_head(pool:23)
  def nodes_head(args = {})
    if args.has_key?(:pool)
      if args[:pool].instance_of?(Pool)
        pool_id = args[:pool].id
      else
        pool_id = args[:pool]
      end
      sql_query = "SELECT DISTINCT persistent_id FROM nodes WHERE model_id = #{self.id} AND pool_id = #{pool_id}"
    else
      sql_query =  "SELECT DISTINCT persistent_id FROM nodes WHERE model_id = #{self.id}"
    end
    node_pids = ActiveRecord::Base.connection.execute(sql_query).values
    return node_pids.map {|pid| Node.latest_version(pid)}
  end

  def self.for_identity_and_pool(identity, pool)
    # Cancan 1.6.8 was producing incorrect query, for accessible_by:
    #SELECT "models".* FROM "models" INNER JOIN "pools" ON "pools"."id" = "models"."pool_id" WHERE (("models"."pool_id" IS NULL) OR ("pools"."owner_id" = 134))
    # So, lets' write something custom:
    Model.joins("LEFT OUTER JOIN pools ON models.pool_id = pools.id").where("(owner_id = ? AND pool_id = ?) OR pool_id is NULL", identity.id, pool.id)
  end

  def self.for_identity(identity)
    # Cancan 1.6.8 was producing incorrect query, for accessible_by:
    #SELECT "models".* FROM "models" INNER JOIN "pools" ON "pools"."id" = "models"."pool_id" WHERE (("models"."pool_id" IS NULL) OR ("pools"."owner_id" = 134))
    # So, lets' write something custom:
    Model.joins("LEFT OUTER JOIN pools ON models.pool_id = pools.id\n" +
    "LEFT OUTER JOIN access_controls ON access_controls.pool_id = models.pool_id").where("(owner_id = ?) OR models.pool_id is NULL OR access_controls.identity_id = ?", identity.id, identity.id)
  end


  # Return true if this model is the file_entity for this identity
  def file_entity?
    code == FILE_ENTITY_CODE
  end

  def self.file_entity
    Model.where(code: FILE_ENTITY_CODE).first_or_create!(code: FILE_ENTITY_CODE, name: "File Entity", fields_attributes: [{'code' => 'file_name', 'type' => 'TextField', 'name' => "Filename"}, {'code' => 'bucket', 'type' => 'TextField', 'name' => "Bucket"},{'code' => 'storage_location_id', 'type' => 'TextField', 'name' => "Storage Location ID"}, {'code' => 'file_entity_type', 'type' => 'TextField', 'name' => "Type of File"},{'code' => 'mime_type', 'type' => 'TextField', 'name' => "Mime Type"},{'code' => 'content_type', 'type' => 'TextField', 'name' => "Content Type"}, {'code' => 'file_size', 'type' => 'IntegerField', 'name' => "File Size"}] ) do |file_entity_model|
      file_name_field = file_entity_model.fields.select {|f| f.code == 'file_name' }.first
      file_name_field.save
      file_entity_model.label_field = file_name_field
    end
  end
  
  # @return [Boolean] current value of allow_file_bindings attribute
  def allows_file_bindings?
    return allow_file_bindings
  end

  def init
    #self.fields ||= []
    #self.associations ||= []
  end

  def index
    ## only index the most recent version of each node
    max_ids = Node.unscoped.select('max(id) as max_id').where('model_id = ?', self.id).group(:persistent_id).map(&:max_id)
    Bindery.index(Node.find(max_ids).map {|m| m.as_index_document })
  end

  # Keys used in Node data corresponding to all Fields in this Model
  def keys
    field_ids.map {|field_id| field_id.to_s}
  end

  # Field codes corresponding to all Fields in this Model -- these are used to generate the solr documents
  def field_codes
    @field_codes ||= fields.map{|f| f.code}
  end

  def map_field_codes_to_id_strings
    if @field_codes_and_id_strings
      return @field_codes_and_id_strings
    else
      @field_codes_and_id_strings = {}
      fields.each do |field|
        @field_codes_and_id_strings[field.code] = field.to_param
      end
      return @field_codes_and_id_strings
    end
  end

  # Returns a copy of `source_data` with field codes converted to the id strings for the corresponding Field with each code
  # Does not modify values where the key (field_code) does not correspond to any Fields on the model
  # See also Model#map_field_codes_to_id_strings
  # @param [Hash] source_data to be converted
  def convert_data_field_codes_to_id_strings(source_data)
    new_data = source_data.dup
    map_field_codes_to_id_strings.each_pair do |field_code,id_string|
      new_data[id_string] = new_data.delete(field_code) unless new_data[field_code].nil?
    end
    new_data
  end

  def self.field_name(label)
    if label.nil? || label.empty?
      UUID.new.generate
    else
      label.downcase.gsub(/\s+/, '_').gsub(/\W+/, '')
    end
  end

  # The key to use for looking up the node label within the data on nodes belonging to this Model
  # Currently hard-coded as the stringified id of the Model's label_field
  def label_key
    label_field_code
  end

  def label_field_code
    result = Field.where(id:label_field_id).select(:code).first
    if result
     return result.code
    else
      return nil
    end
  end

  def to_uri
    "http://api.databindery.com/api/v1/pools/#{self.pool_id}/models/#{self.id}"
  end

  # Return the Model's array of fields and associations as they are ordered in the edit view
  def ordered_fields_and_associations
    self.fields.concat(self.association_fields)
  end
  
end
