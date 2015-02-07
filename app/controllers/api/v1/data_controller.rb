class Api::V1::DataController < ApplicationController

  include Bindery::Persistence::ElasticSearch::Consumer
  include Bindery::AppliesPerspectives

  # Note: It's important to use +=, not << when appending new query_logic callbacks
  # because that sets a new array rather than appending to the array initialized by
  # Bindery::Persistence::ElasticSearch::Consumer
  # This pattern for preventing bleed-over also applies to subclasses
  self.query_logic += [:apply_user_query, :apply_facet_config_to_query, :apply_index_fields_to_query, :apply_sorting, :apply_audience_filters]

  before_filter :load_pool
  load_and_authorize_resource instance_name: :node, class: Node, find_by: :persistent_id, only: [:show]

  before_filter :set_perspective
  before_filter :convert_facet_fields_params
  before_filter :convert_sort_fields_params
  before_filter :load_configuration

  def index
    (@response, @document_list) = get_search_results
    render json: json_response
  end

  def show
    render json: {"foo"=>"bar"}
  end

  private

  def get_search_results(extra_params={})
    @pool.search(query_builder(extra_params))
  end

  # Given an Array of persistent_ids, loads the corresponding Nodes
  # @document_list [Array] Array of persistent_ids of Nodes that should be loaded
  def marshall_nodes(node_id_list)
    node_id_list.map{|nid| Node.find_by_persistent_id(nid)}
  end

  def json_response(options={})
    if params["nodesOnly"] || params["queries"] || options[:nodes_only]
      @marshalled_results ||= marshall_nodes(@document_list.map{|d| d["_id"]})
      return @marshalled_results
    else
      return default_json_response
    end
  end

  def default_json_response(options={})
    json_response = @response
    if options.fetch(:marshall, false)
      @marshalled_results ||= marshall_nodes(@document_list.map{|d| d["_id"]})
      json_response["hits"]["hits"] = @marshalled_results
    end
    json_response
  end

  def apply_facet_config_to_query(query_builder, user_parameters)
    @exhibit.facets.uniq.each do |facet_field|
      query_builder.aggregations.add_facet(facet_field.code)
    end
    return query_builder, user_parameters
  end

  def apply_index_fields_to_query(query_builder, user_parameters)
    # query_builder.fields = query_builder.fields + @exhibit.index_fields
    query_builder.fields += ["_id","_bindery_pool","_bindery_model"]
    query_builder.fields += @exhibit.index_fields.map{|f| f.code}
    return query_builder, user_parameters
  end


  def load_configuration
    # Do nothing for now
  end

  def apply_user_query(query_builder,user_parameters)
    # query_builder.set_query(:bool, {})
    if user_parameters[:q]
      query_builder.query.query = user_parameters[:q]
    end
    apply_facet_queries(query_builder,user_parameters)
    return query_builder, user_parameters
  end

  def apply_facet_queries(query_builder,user_parameters)
    if user_parameters[:f].kind_of?(Hash)
      if query_builder.query.nil?
        query_builder.set_query(:bool, {})
      end
      if query_builder.query.class == Bindery::Persistence::ElasticSearch::Query::FilterTypes::Bool
        bool_query = query_builder.query
      else
        # replace the query_builder.query with a Bool and restore the original query withing bool['must'] (unless the original is empty)
        original_query = query_builder.query
        bool_query = query_builder.set_query(:bool, {})
        bool_query.must.filters << original_query unless original_query.empty?
        # bool_query = query_builder.query.add_filter(:bool)
      end
      user_parameters[:f].each_pair do |field_code, facet_value|
        bool_query.add_must_match({field_code => facet_value})
      end
    end
    return query_builder, user_parameters
  end

  def apply_sorting(query_builder,user_parameters)
    unless user_parameters.fetch(:sort,[]).empty?
      user_parameters[:sort].each do |sort_entry|
        query_builder.sort <<  sort_entry
      end
    end
    return query_builder, user_parameters
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
          params[:f][field.code] = value
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
          sort_entries << {field.code => direction}
        end
      end
      unless params[:sort].nil? || params[:sort].empty?
        sort_entries << params[:sort]
      end
      params[:sort] = sort_entries
    end
  end


end