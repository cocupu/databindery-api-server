class Api::V1::PoolDataController < ApplicationController
  include Api::V1::SwaggerDefs::Data
  load_and_authorize_resource :identity, :find_by => :short_name
  before_filter :load_pool
  load_and_authorize_resource :pool
  load_and_authorize_resource instance_name: :node, class: Node, find_by: :persistent_id, only: [:show]
  load_resource :model, through: :node, singleton: true, only: [:show]
  
  before_filter :set_perspective
  before_filter :load_configuration
  before_filter :load_model_for_grid
  before_filter :convert_facet_fields_params
  before_filter :convert_sort_fields_params

  include Blacklight::Controller
  def layout_name
    'application'
  end
  include Blacklight::Catalog
  include Bindery::AppliesPerspectives
  include GoogleRefineSupport

  solr_search_params_logic << :add_pool_to_fq << :add_index_fields_to_qf << :ensure_model_filtered_for_grid << :apply_audience_filters

      # get search results from the solr index
  # Had to override the whole method (rather than using super) in order to add json support
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



  # Provides a pool overview with models, perspectives and facets
  def overview
    authorize! :show, @pool
    (@response, @document_list) = get_search_results(rows:0)
    render :json=>{id:@pool.id, models:@pool.models.as_json, perspectives:@pool.exhibits.as_json, facets:@response["facet_counts"]["facet_fields"], numFound:@response["response"]["numFound"] }
  end
  
  
  protected

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

  def load_configuration
    @blacklight_config = Blacklight::Configuration.new
    @blacklight_config.configure do |config|
      ## Default parameters to send to solr for all search-like requests. See also SolrHelper#solr_search_params
      config.default_solr_params = { 
        :qt => 'search',
        :fl => '*', 
        :rows => 10 
      }

      ## Default parameters to send on single-document requests to Solr. These settings are the Blackligt defaults (see SolrHelper#solr_doc_params) or 
      ## parameters included in the Blacklight-jetty document requestHandler.
      #
      #config.default_document_solr_params = {
      #  :qt => 'document',
      #  ## These are hard-coded in the blacklight 'document' requestHandler
      #  # :fl => '*',
      #  # :rows => 1
      #  # :q => '{!raw f=id v=$id}' 
      #}

      # solr field configuration for search results/index views
      config.show.title_field = 'title'
      config.index.display_type_field = 'model_name'

      # solr field configuration for document/show views
      config.show.title_field = 'title'
      config.show.display_type_field = 'model_name'

      # solr fields that will be treated as facets by the blacklight application
      #   The ordering of the field names is the order of the display
      #
      # Setting a limit will trigger Blacklight's 'more' facet values link.
      # * If left unset, then all facet values returned by solr will be displayed.
      # * If set to an integer, then "f.somefield.facet.limit" will be added to
      # solr request, with actual solr request being +1 your configured limit --
      # you configure the number of items you actually want _displayed_ in a page.    
      # * If set to 'true', then no additional parameters will be sent to solr,
      # but any 'sniffed' request limit parameters will be used for paging, with
      # paging at requested limit -1. Can sniff from facet.limit or 
      # f.specific_field.facet.limit solr request params. This 'true' config
      # can be used if you set limits in :default_solr_params, or as defaults
      # on the solr side in the request handler itself. Request handler defaults
      # sniffing requires solr requests to be made with "echoParams=all", for
      # app code to actually have it echo'd back to see it.  
      #
      # :show may be set to false if you don't want the facet to be drawn in the 
      # facet bar
      exhibit.facets.uniq.each do |field|
        unless blacklight_config.facet_fields.keys.include?( Node.solr_name(field) )
          if field.kind_of?(Field)
            if field.name.nil?
              field.name = field.code.humanize
            end
            config.add_facet_field Node.solr_name(field), :label => field.name.humanize, limit: 10
          else
            case field
              when "model_name"
                config.add_facet_field Node.solr_name(field, type: 'facet'), :label => "Model", limit: 10
              when String
                config.add_facet_field Node.solr_name(field, type: 'facet'), :label => field.humanize, limit: 10
            end
          end
        end
      end

      # Have BL send all facet field names to Solr, which has been the default
      # previously. Simply remove these lines if you'd rather use Solr request
      # handler defaults, or have no facets.
      config.add_facet_fields_to_solr_request!

      # solr fields to be displayed in the index (search results) view
      #   The ordering of the field names is the order of the display 
      exhibit.index_fields.uniq.each do |field|
        #if f == "model_name"
        #  config.add_index_field Node.solr_name(f, type: 'facet'), :label => "Model"
        #else
        #  config.add_index_field Node.solr_name(f), :label => f.humanize+':'
        #end
        unless blacklight_config.index_fields.keys.include?( Node.solr_name(field) )
          if field.kind_of?(Field)
            if field.name.nil?
              field.name = field.code.humanize
            end
            config.add_index_field Node.solr_name(field), :label => field.name+':'
          else
            case field
              when "model_name"
                config.add_index_field Node.solr_name(field, type: 'facet'), :label => "Model"
              when String
                config.add_index_field Node.solr_name(field), :label => field.humanize+':'
            end
          end
        end
      end
      # query_fields = exhibit.pool.models.map {|model| model.keys.map{ |key| Node.solr_name(key) } }.flatten.uniq
      #solr_parameters[:qf] = query_fields + ["pool"]

      # solr fields to be displayed in the show (single result) view
      #   The ordering of the field names is the order of the display 
      exhibit.index_fields.uniq.each do |field|
        unless blacklight_config.show_fields.keys.include?( Node.solr_name(field) )
          if field.kind_of?(Field)
            if field.name.nil?
              field.name = field.code.humanize
            end
            config.add_show_field Node.solr_name(field), :label => field.name+':'
          else
            case field
              when "model_name"
                config.add_show_field Node.solr_name(field, type: 'facet'), :label => "Model"
              when String
                config.add_show_field Node.solr_name(field), :label => field.humanize+':'
            end
          end
        end
      end

      # "fielded" search configuration. Used by pulldown among other places.
      # For supported keys in hash, see rdoc for Blacklight::SearchFields
      #
      # Search fields will inherit the :qt solr request handler from
      # config[:default_solr_parameters], OR can specify a different one
      # with a :qt key/value. Below examples inherit, except for subject
      # that specifies the same :qt as default for our own internal
      # testing purposes.
      #
      # The :key is what will be used to identify this BL search field internally,
      # as well as in URLs -- so changing it after deployment may break bookmarked
      # urls.  A display label will be automatically calculated from the :key,
      # or can be specified manually to be different. 

      # This one uses all the defaults set by the solr request handler. Which
      # solr request handler? The one set in config[:default_solr_parameters][:qt],
      # since we aren't specifying it otherwise. 
      
      config.add_search_field 'all_fields', :label => 'All Fields'
      
      # "sort results by" select (pulldown)
      # label in pulldown is followed by the name of the SOLR field to sort by and
      # whether the sort is ascending or descending (it must be asc or desc
      # except in the relevancy case).
      config.add_sort_field 'score desc, title asc', :label => 'relevance'
      config.add_sort_field 'timestamp desc, title asc', :label => 'recently modified'
      config.add_sort_field 'title asc', :label => 'title'

      
      # If there are more than this many search results, no spelling ("did you 
      # mean") suggestion is offered.
      config.spell_max = 5
    end
  end

  def add_pool_to_fq(solr_parameters, user_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << "pool:#{exhibit.pool_id}"

  end

  # The fields set in qf are the ones that we query on. A pretty good default is to use the fields we display.
  def add_index_fields_to_qf(solr_parameters, user_parameters)
    solr_parameters[:qf] ||= []
    solr_parameters[:qf] << 'title'
    blacklight_config.index_fields.each do |field_name, obj|
      solr_parameters[:qf] << field_name
    end
  end

  # Load the selected model for use in generating grid column sorting, etc.
  def load_model_for_grid
    if params["model_id"]
      @model_for_grid = @pool.models.find(params["model_id"])
    else
      #if (params[:format].nil? || params[:format] == "html") && params["view"] != "browse"
      if params["view"] == "grid"
        @model_for_grid = @pool.models.first
      end
    end
  end

  def ensure_model_filtered_for_grid(solr_parameters, user_parameters)
    unless @model_for_grid.nil?
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << "model:#{@model_for_grid.id}"
    end
  end

  def apply_audience_filters(solr_parameters, user_parameters)
    unless can? :edit, @pool
      @pool.apply_solr_params_for_identity(current_identity, solr_parameters, user_parameters)
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
          params[:f][field.solr_name(type: "facet")] = value
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
          sort_entries << "#{field.solr_name} #{direction}"
        end
      end
      unless params[:sort].nil? || params[:sort].empty?
        sort_entries << params[:sort]
      end
      params[:sort] = sort_entries.join(",")
    end
  end


end
