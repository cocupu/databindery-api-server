class Exhibit < ActiveRecord::Base
  include ActiveModel::ForbiddenAttributesProtection
  belongs_to :pool
  has_many :filters, class_name:"SearchFilter", as: :filterable
  validates :pool, presence: true
  serialize :facets
  serialize :index_fields

  after_initialize :init
  accepts_nested_attributes_for :filters, allow_destroy: true

  def init
    self.facets ||= []
    self.index_fields ||= []
  end

  # Apply the Exhibit's search logic to Blacklight Controller solr_params_logic
  # @param solr_parameters [Hash] parameters hash that Blacklight will render as Solr query
  # @param user_parameters [Hash] parameters from http request
  def apply_solr_params_logic(solr_parameters, user_parameters)
    SearchFilter.apply_solr_params_for_filters(filters, solr_parameters, user_parameters)
    #filters.each do |filter|
    #  filter.apply_solr_params(solr_parameters, user_parameters)
    #end
    return solr_parameters, user_parameters
  end
end
