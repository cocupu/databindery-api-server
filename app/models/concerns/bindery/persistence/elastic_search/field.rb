module Bindery::Persistence::ElasticSearch::Field

  def elasticsearch_attributes
    {type:elasticsearch_datatype}
  end

  # Core elasticsearch datatypes: string, number, boolean, date
  def elasticsearch_datatype
    case self
      when TextArea,TextField
        'string'
      when IntegerField
        'integer'
      when NumberField
        'float'
      when BooleanField
        'boolean'
      when DateField
        'date'
      when AttachmentField
        'attachment'
      when ArrayField
        'string'
      else
        'string'
    end
  end
end