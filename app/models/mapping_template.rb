class MappingTemplate < ActiveRecord::Base
  serialize :model_mappings, Array  # one row per model

  after_initialize :init
  belongs_to :pool
  belongs_to :owner, class_name: "Identity", :foreign_key => 'identity_id'
  validates :owner, presence: true

  def init
    self.model_mappings ||= []
  end

  def attributes=(attrs)
    attrs[:row_start] = attrs.delete(:row_start).to_i if attrs[:row_start]
    super(attrs)
  end

  def model_mappings_attributes=(model_mappings_attributes)
    # model_mappings_attributes is a hash whose keys are basically array indexes, so each_pair basically gives you []index, value]
    model_mappings_attributes.each_pair do |index, value|
      model_attributes = value.with_indifferent_access
      model = Model.find(model_attributes[:model_id]) if model_attributes[:model_id]
      model = Model.find_or_initialize_by(name: model_attributes[:name], pool_id:pool.id) unless (model && model.pool_id == pool.id)
      model.owner = owner
      model.name = model_attributes[:name] # Updates name on pre-existing models if it has changed
      model_mapping = {:field_mappings => model_attributes[:field_mappings_attributes].values, :name=>model_attributes[:name], :label=>model_attributes[:label]}
      model_mapping[:field_mappings].each do |map|
        map_wia = map.with_indifferent_access
        unless map_wia[:label].nil? || map_wia[:label].empty?
          field_code = Model.field_name(map_wia[:label])
          unless field_code.blank?
            field = Field.create(:code => field_code, :name =>map_wia[:label])
            model.fields << field
            model.label_field = field if model_attributes[:label] == map_wia[:source] || model_attributes[:label].to_i == map_wia[:source]
            map[:field] = field_code
          end
        end
      end
      begin
        model.save!
      rescue  ActiveRecord::RecordInvalid => e
        model_mappings << model_mapping
        raise e
      end
      model_mapping[:model_id] = model.id
      model_mappings[index.to_i] = model_mapping
    end
  end

end
