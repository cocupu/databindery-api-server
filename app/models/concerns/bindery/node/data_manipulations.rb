module Bindery::Node::DataManipulations
  extend ActiveSupport::Concern

  # Getter for field values
  # Uses #lookup_field_code to figure out which field key to use
  # @example
  #   field_value("full_name")
  # @example find by field code
  #   field_value("full_name", :find_by => :code)
  # @example find by field code
  #   field_value(48, :find_by => :id)
  # @example find by field name
  #   field_value("Full Name", :find_by => :name)
  def field_value(field_identifier, options={})
    data[lookup_field_code(field_identifier, options)]
  end

  # Sets field value corresponding to identifier
  # Supports same options as #field_value
  def set_field_value(field_identifier, value, options={})
    id_string = lookup_field_code(field_identifier, options)
    if id_string.nil?
      raise ArgumentError, "Couldn't set field value. This node's model (#{model.name}) doesn't have a field whose #{options[:find_by]} is set to #{field_identifier}. Called on node #{self.id}"
    end
    return data[id_string] = value
  end

  # Returns the id string corresponding to the given field_identifier
  # Assumes field_identifier is field code unless you provide :find_by in the options
  # @example
  #   lookup_field_code("full_name")
  #   => "full_name"
  # @example find by field code (default)
  #   lookup_field_code("full_name", :find_by => :code)
  #   => "full_name"
  # @example find by field id
  #   lookup_field_code(48, :find_by => :code)
  #   => "full_name"
  # @example find by field name
  #   lookup_field_code("Full Name", :find_by => :name)
  #   => "full_name"
  def lookup_field_code(field_identifier, options={})
    if options[:find_by]
      field = model.fields.where(options[:find_by] => field_identifier).select(:code,:id).first
      return field.to_param unless field.nil?
    else
      return field_identifier.to_s
    end
  end

  # Returns a copy of `source_data` with field codes converted to the id strings for the corresponding Field with each code
  # Does not modify values where the key (field_code) does not correspond to any Fields on the node's model
  # See also Model#convert_data_field_codes_to_id_strings
  # @param [Hash] source_data to be converted
  def convert_data_field_codes_to_id_strings(source_data)
    model.convert_data_field_codes_to_id_strings(source_data)
  end

  # Converts field codes to id strings within node's current data
  # See #convert_data_field_codes_to_id_strings
  def convert_data_field_codes_to_id_strings!
    self.data = convert_data_field_codes_to_id_strings(self.data)
  end

end
