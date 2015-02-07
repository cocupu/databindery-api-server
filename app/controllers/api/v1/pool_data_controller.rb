class Api::V1::PoolDataController < Api::V1::DataController
  include Api::V1::SwaggerDefs::Data

  load_and_authorize_resource :pool
  load_resource :model, through: :node, singleton: true, only: [:show]

  # Provides a pool overview with models, perspectives and facets
  # def overview
  #   authorize! :show, @pool
  #   (@response, @document_list) = get_search_results(rows:0)
  #   render :json=>{id:@pool.id, models:@pool.models.as_json, perspectives:@pool.exhibits.as_json, facets:@response["facet_counts"]["facet_fields"], numFound:@response["response"]["numFound"] }
  # end


end
