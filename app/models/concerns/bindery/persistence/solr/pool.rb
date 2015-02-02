module Bindery::Persistence::Solr::Pool
  extend ActiveSupport::Concern

  def apply_query_params_for_identity(identity, solr_params={}, user_params={})
    apply_solr_params_for_identity(identity, solr_params, user_params)
  end

  def apply_solr_params_for_identity(identity, solr_params={}, user_params={})
    # Unless user has explicit read/edit access, apply filters based on audience memberships
    if access_controls.where(identity_id:identity.id).empty?
      filters = []
      audiences_for_identity(identity).each do |audience|
        filters.concat(audience.filters)
      end
      if filters.empty?
        SearchFilter.apply_solr_params_for_filters(default_filters, solr_params, user_params)
      else
        SearchFilter.apply_solr_params_for_filters(filters, solr_params, user_params)
      end
    end
    return solr_params, user_params
  end

end