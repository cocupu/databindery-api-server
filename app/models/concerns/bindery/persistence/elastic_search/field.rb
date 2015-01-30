module Bindery::Persistence::ElasticSearch::Field

  def elasticsearch_attributes
    {type:elasticsearch_datatype}
  end

  # Core elasticsearch datatypes: string, number, boolean, date
  def elasticsearch_datatype
    case self.class
      when Field,TextArea,TextField
        'string'
      when NumberField, IntegerField
        'number'
      when BooleanField
        'boolean'
      when DateField
        'date'
      when AttachmentField
        'attachment'
      else
        'string'
    end
  end
end