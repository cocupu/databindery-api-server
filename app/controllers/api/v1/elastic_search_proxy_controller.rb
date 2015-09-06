class Api::V1::ElasticSearchProxyController < Api::V1::DataController
  include Api::V1::SwaggerDefs::Data

  # call load_pool with parama[:id] instead of params[:pool_id]
  prepend_before_action { load_pool(id_param: :id) }
  # Don't inject any query logic
  self.query_logic = [:apply_submitted_query_body]

  def index
    authorize! :read, @pool # Require read access (not query permission)
    super
  end

  private

  # Override set_perspective (inherited from AppliesPerspectives via DataController) to prevent it from doing anything
  def set_perspective
    # do nothing
  end

  def apply_submitted_query_body(query_builder, user_parameters)
    if user_parameters[:body]
      query_builder.body = user_parameters[:body]
    end
  end

end
