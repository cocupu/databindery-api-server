class Field < ActiveRecord::Base
  include Bindery::Persistence::ElasticSearch::Field

  has_and_belongs_to_many :models
  validates :name, presence: true, if: "code.nil?"
  before_create :initialize_name_and_code
  # after_create  :initialize_uri

  def to_param
    self.code
  end

  # Include the type in json representation of Fields
  def as_json(options=nil)
    json = super
    json.merge({"type"=>self.type.to_s})
  end

  def sanitize(value)
    value
  end

  def field_name_for_index(options={})
    Node.field_name_for_index(self, options)
  end

  # Finds or Creates a canonical field with the given code
  def self.canonical(field_code)
    Field.where(code: field_code).first_or_create!(name: field_code.humanize)
  end

  private

  # If code is empty, sets it to downcased version of the name.
  # If name is empty, sets it to humanized version of the code.
  # Assumes that a validator ensures that there is at least a code or a name set.
  def initialize_name_and_code
    self.code ||= self.name.gsub(" ", "_").downcase
    self.name ||= self.code.gsub("_", " ").capitalize
  end

  # def initialize_uri
  #   if self.uri.nil?
  #     self.uri  ||= "http://api.databindery.com/api/v1/pools/#{models.first.pool.to_param}/fields/#{self.to_param}"
  #     self.save
  #   end
  # end
end

class TextField < Field;end
class TextArea < Field;end
class NumberField < Field;end
class IntegerField < NumberField;end
class BooleanField < Field;end
class AttachmentField < Field;end
class DateField < Field
  def sanitize(value)
    Time.parse(value).utc.iso8601 unless value.nil?
  end
end
class OrderedListAssociation < Field
  validates :name, exclusion: { in: %w(undefined), message: "can't be \'%{value}\'" }
  before_create :initialize_label

  def model
    Model.find(references)
  end

  private
  def initialize_label
    self.label ||= Model.find(self[:references]).name.capitalize
  end
end