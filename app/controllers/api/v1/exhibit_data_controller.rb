# This was previously CatalogController
# When refactoring to use ElasticSearch, look to make this share modules & behavior with PoolDataController - MZ Jan 2015
class Api::V1::ExhibitDataController < ApplicationController
  load_and_authorize_resource :exhibit
  load_and_authorize_resource instance_name: :node, class: Node, find_by: :persistent_id, only: [:show]

  before_filter :load_configuration

  include Blacklight::Controller
  def layout_name
    'application'
  end
  include Blacklight::Catalog
  include Bindery::AppliesPerspectives

  solr_search_params_logic << :add_pool_to_fq << :add_index_fields_to_qf << :process_sort_field_params

  protected

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
      @exhibit.facets.uniq.each do |key|
        if key == "model_name"
          config.add_facet_field Node.field_name_for_index(key, type: 'facet'), :label => "Model", limit: 10
        else
          config.add_facet_field Node.field_name_for_index(key, type: 'facet'), :label => key.humanize, limit: 10
        end
      end


      # Have BL send all facet field names to Solr, which has been the default
      # previously. Simply remove these lines if you'd rather use Solr request
      # handler defaults, or have no facets.
      config.add_facet_fields_to_solr_request!

      # solr fields to be displayed in the index (search results) view
      #   The ordering of the field names is the order of the display 
      @exhibit.index_fields.uniq.each do |f|
        if f == "model_name"
          config.add_index_field Node.field_name_for_index(f, type: 'facet'), :label => "Model"
        else
          config.add_index_field Node.field_name_for_index(f), :label => f.humanize+':'
        end
      end
      # query_fields = @exhibit.pool.models.map {|model| model.keys.map{ |key| Node.field_name_for_index(key) } }.flatten.uniq
      #solr_parameters[:qf] = query_fields + ["pool"]

      # solr fields to be displayed in the show (single result) view
      #   The ordering of the field names is the order of the display 
      @exhibit.index_fields.uniq.each do |f|
        if f == "model_name"
          config.add_show_field Node.field_name_for_index(f, type: 'facet'), :label => "Model"
        else
          config.add_show_field Node.field_name_for_index(f), :label => f.humanize+':'
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
    solr_parameters[:fq] << "pool:#{@exhibit.pool_id}"

  end

  # The fields set in qf are the ones that we query on. A pretty good default is to use the fields we display.
  def add_index_fields_to_qf(solr_parameters, user_parameters)
    solr_parameters[:qf] ||= []
    solr_parameters[:qf] << 'title'
    blacklight_config.index_fields.each do |field_name, obj|
      solr_parameters[:qf] << field_name
    end
  end

  def process_sort_field_params(solr_parameters, user_parameters)
    if user_parameters.has_key?(:sort_fields)
      sorts = []
      #if solr_parameters[:sort]
      #  sorts << solr_parameters[:sort]
      #end
      user_parameters[:sort_fields].each do |sort_options|
        field = Field.find(sort_options[:field_id])
        sorts << "#{field.field_name_for_index} #{sort_options[:direction]}"
      end
      solr_parameters[:sort] = sorts.join(",")
    end

  end

end
