module GoogleRefineSupport
  extend ActiveSupport::Concern

  included do
    solr_search_params_logic << :apply_google_refine_query_params
  end

  #
  # Google Refine Support
  #
  def do_refine_style_query
    @marshalled_results ||= {}
    params["queries"].each_pair do |query_name, multi_query_params|
      @google_refine_query_params = multi_query_params
      (@response, @document_list) = get_search_results
      # Marshall nodes if requested.  Default to returning json based on Google Refine Resolver API spec
      if params["marshall_nodes"]
        @marshalled_results[query_name] = {result: @document_list.map {|doc| Node.find_by_persistent_id(doc['id'])}}
      else
        @marshalled_results[query_name] = {result: @document_list.map {|doc| {id:doc["id"], name:doc["title"], type:[doc["model_name"]], score:doc["score"], match:true }}}
      end
      @marshalled_results[query_name].merge!(@response["response"].except("docs"))
    end
  end

  # If @google_refine_query_params is set, applies those parameters to the solr query params
  # @example Sample Google Refine Query
  #   "queries" => {
  #     "q1" => {
  #      "query" => "Ford Taurus",
  #          "limit" => 3,
  #          "type" => "/automotive/model",
  #          "type_strict" => "any",
  #          "properties" => [
  #          { "p" => "year", "v" => 2009 },
  #          { "pid" => "/automotive/model/make" , "v" => "/en/ford" }
  #          ]
  #    },{
  #     "q2" => {
  #        "query"=>"Dodge Neon"
  #     }
  #    }
  def apply_google_refine_query_params(solr_parameters, user_parameters)
    unless @google_refine_query_params.nil?
      query_params = @google_refine_query_params
      #"type_strict" => "any"
      solr_parameters["q"] = query_params["query"]
      solr_parameters["rows"] =  query_params["limit"] unless query_params["limit"].nil?
      solr_parameters[:fq] ||= []
      if query_params["type"] # && query_params["type_strict"] == "should"
        solr_parameters[:fq] << "+#{Node.solr_name("model_name", type:"facet")}:\"#{query_params["type"]}\""
      end
      # Examples of property_query values
      #{ "p" => "year", "v" => 2009 },
      #{ "pid" => "/automotive/model/make" , "v" => "/en/ford" }
      query_params["properties"] ||= []
      query_params["properties"].each do |property_query|

        if property_query["p"]
          property_name =  property_query["p"]
        elsif property_query["pid"]
          property_name = @pool.all_fields.select {|f| f["uri"] == property_query["pid"]}.first["name"]
        end
        # model_id is stored in the "model" solr field.  Map the query accordingly.
        if property_name == "model_id"
          property_name = "model"
        end
        solr_parameters[:fq] << "+#{Node.solr_name(property_name)}:\"#{property_query["v"]}\"" unless (property_name.nil? || property_query["v"].nil?)
      end
      solr_parameters[:fl] = "*,score"
    end
  end

end