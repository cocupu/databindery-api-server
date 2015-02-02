module DataController
  extend ActiveSupport::Concern

  included do
    include Bindery::AppliesPerspectives
    include GoogleRefineSupport
    include Bindery::Persistence::ElasticSearch::Consumer

    search_params_logic << :add_pool_to_fq << :add_index_fields_to_qf << :apply_audience_filters
  end

  # get search results from the index
  def index

    if params["queries"]
      do_refine_style_query
    else
      (@response, @document_list) = get_search_results
    end

    @filters = params[:f] || []

    respond_to do |format|
      format.html { render json: json_response }
      format.json { render json: json_response }
      format.rss  { render :layout => false }
      format.atom { render :layout => false }
    end
  end

  def show

  end

  protected

  def get_search_results
    __elasticsearch__.search()
  end

  def apply_audience_filters(solr_parameters, user_parameters)
    unless can? :edit, @pool
      @pool.apply_query_params_for_identity(current_identity, solr_parameters, user_parameters)
    end
  end

  # Allows facet queries by field id instead of Solr field name
  # @example Facet on nodes where the value of field 45 is "Mint"
  #   get :index, :pool_id=>1, identity_id:'sassy', "facet_fields" => {45 => "Mint"}
  # Has to be run as a before filter instead of part of solr_search_params_logic to ensure that Blacklight intercepts & converts the facets as if they were regular facet queries.
  def convert_facet_fields_params
    if params[:facet_fields]
      params[:f] ||= {}
      params[:facet_fields].each_pair do |field_id,value|
        begin
          field = Field.find(field_id.to_i)
          params[:f][field.field_name_for_index(type: "facet")] = value
        end
      end
    end
  end

  # Allows sorting by field id instead of Solr field name
  # @example Sort by field 45 descending
  #   get :index, :pool_id=>1, identity_id:'sassy', "sort_fields" => {47 => "desc"}
  # Has to be run as a before filter instead of part of solr_search_params_logic to ensure that Blacklight intercepts & converts the sort params as if they were regular sort params.
  def convert_sort_fields_params
    if params[:sort_fields]
      unless params[:sort_fields].kind_of?(Array)
        params[:sort_fields] = JSON.parse(params[:sort_fields])
      end
      sort_entries = []
      params[:sort_fields].each do |sort_entry|
        field_id = sort_entry.keys.first
        direction = sort_entry.values.first
        begin
          field = Field.find(field_id.to_i)
          sort_entries << "#{field.field_name_for_index} #{direction}"
        end
      end
      unless params[:sort].nil? || params[:sort].empty?
        sort_entries << params[:sort]
      end
      params[:sort] = sort_entries.join(",")
    end
  end

  # Given an Array of persistent_ids, loads the corresponding Nodes
  # @document_list [Array] Array of persistent_ids of Nodes that should be loaded
  def marshall_nodes(node_id_list)
    node_id_list.map{|nid| Node.find_by_persistent_id(nid)}
  end

  def json_response
    @marshalled_results ||= marshall_nodes(@document_list.map{|d| d["id"]})
    if params["nodesOnly"] || params["queries"]
      return @marshalled_results
    else
      return default_json_response
    end
  end

  def default_json_response
    json_response = @response
    #json_response["docs"] = @response["response"]["docs"].map {|solr_doc| serialize_work_from_solr(solr_doc) }
    json_response["docs"] = @marshalled_results
    json_response
  end
end