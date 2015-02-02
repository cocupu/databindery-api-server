class Api::V1::PoolDataController < ApplicationController
  include Api::V1::SwaggerDefs::Data
  before_filter :load_pool
  load_and_authorize_resource :pool
  load_and_authorize_resource instance_name: :node, class: Node, find_by: :persistent_id, only: [:show]
  load_resource :model, through: :node, singleton: true, only: [:show]
  
  before_filter :set_perspective
  before_filter :load_configuration
  before_filter :convert_facet_fields_params
  before_filter :convert_sort_fields_params


  # Provides a pool overview with models, perspectives and facets
  def overview
    authorize! :show, @pool
    (@response, @document_list) = get_search_results(rows:0)
    render :json=>{id:@pool.id, models:@pool.models.as_json, perspectives:@pool.exhibits.as_json, facets:@response["facet_counts"]["facet_fields"], numFound:@response["response"]["numFound"] }
  end


end
