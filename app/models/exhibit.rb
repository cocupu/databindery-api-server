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

  # Apply the Exhibit's search logic the Controller's query params logic
  # @param query_parameters [Hash] parameters hash that the Controller with render as a query to the index (elasticsearch or solr)
  # @param user_parameters [Hash] parameters from http request
  def apply_query_params_logic(query_parameters, user_parameters)
    SearchFilter.apply_query_params_for_filters(filters, query_parameters, user_parameters)
    return query_parameters, user_parameters
  end
end
