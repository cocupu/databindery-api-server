module Bindery::Node::Associations
  extend ActiveSupport::Concern

  # Returns the data entries that are associations according to the model
  def associations
    association_ids = model.association_field_ids
    data.select{|k,v| association_ids.include?(k.to_s) }
  end

  def associations_for_json
    output = {}
    update_file_ids
    model.association_fields.each do |a|
      output[a.name] = []
      if data[a.id.to_s] && data[a.id.to_s].kind_of?(Array)
        data[a.id.to_s].each do |id|
          node = Node.latest_version(id)
          output[a.name] <<  node.association_display if node
        end
      end
    end
    output['undefined'] = []
    if files
      output['files'] = []
      files.each do |file_entity|
        output['files'] << file_entity.association_display
      end
    end
    output
  end

  def association_display
    serializable_hash(:only=>[:id, :persistent_id], :methods=>[:title])
  end

end
