class Audience < ActiveRecord::Base
  belongs_to :audience_category
  has_one :pool, through: :audience_category
  has_many :filters, class_name:"SearchFilter", as: :filterable
  has_and_belongs_to_many :members, class_name: "Identity"#, inverse_of: :audiences

  accepts_nested_attributes_for :filters, allow_destroy: true

  # Index-agnostic method name (aliases to elasticsearch implementation)
  def apply_query_params(query_params, user_params={})
    apply_elasticsearch_params(query_params, user_params)
  end

  # Elasticsearch implementation
  def apply_elasticsearch_params(elasticsearch_params, user_params={})
    filters.each do |filter|
      filter.apply_elasticsearch_params(elasticsearch_params, user_params)
    end
    return elasticsearch_params, user_params
  end

  # Solr Implementation
  def apply_solr_params(solr_params, user_params={})
    filters.each do |filter|
      filter.apply_solr_params(solr_params, user_params)
    end
    return solr_params, user_params
  end

  def as_json(opts=nil)
    h = super(opts)
    h["filters"] = self.filters.as_json
    h["member_ids"] = self.member_ids
    return h
  end
end
