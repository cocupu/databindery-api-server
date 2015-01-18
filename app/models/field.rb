class Field < ActiveRecord::Base
  has_and_belongs_to_many :models
  validates :name, presence: true, if: "code.nil?"
  before_create :initialize_name_and_code

  # Include the type in json representation of Fields
  def as_json(options=nil)
    json = super
    json.merge({"type"=>self.type.to_s})
  end

  def sanitize(value)
    value
  end

  def solr_name(options={})
    Node.solr_name(self, options)
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
    self.code ||= self.name.downcase
    self.name ||= self.code.gsub("_", " ").capitalize
  end
end
class TextField < Field;end
class TextArea < Field;end
class IntegerField < Field;end
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