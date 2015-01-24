class Api::V1::FieldsController < ApplicationController

  load_and_authorize_resource :model, only:[:create]

  before_filter :load_pool
  # load_resource :identity, :find_by => :short_name, only:[:index, :show]
  # load_resource :pool, :find_by => :short_name, :through=>:identity, only:[:index, :show]

  include Blacklight::SolrHelper
  solr_search_params_logic << :add_pool_to_fq
  before_filter :load_configuration, only: :show


  def index
    authorize! :edit, @pool
    @fields = @pool.all_fields
    respond_to do |format|
      format.html { redirect_to identity_pool_search_path(@identity.short_name, @pool.short_name) }
      format.json { render :json=>@fields }
    end
  end

  def show
    authorize! :edit, @pool
    all_fields = @pool.all_fields
    @field = all_fields.select {|f| f["code"] == params[:id]}.first

    extra_controller_params = {}
    field_code = params[:id]
    field_solr_name = Node.solr_name(field_code, type: "facet")
    extra_controller_params[:fq] = "#{field_solr_name}:[* TO *]"
    extra_controller_params["facet.field"] = field_solr_name
    extra_controller_params[:rows] = 0

    solr_response = query_solr(params, extra_controller_params)
    values_info = {"numDocs"=>solr_response["response"]["numFound"],"values"=>hashify_facet_counts(solr_response["facet_counts"]["facet_fields"][field_solr_name])}

    respond_to do |format|
      format.html { redirect_to identity_pool_search_path(@identity.short_name, @pool.short_name) }
      format.json { render :json=>@field.as_json.merge(values_info) }
    end
  end

  def create
    field_code = Model.field_name(params[:field][:name])
    @field = Field.create(params[:field].merge(code: field_code).permit(:id, :name, :type, :code, :uri, :multivalue))
    @model.fields << @field
    @model.save!
    render json: @field
  end

  def new
    field_code = Model.field_name(params[:name])
    field = params.permit(:name, :type).merge(code: field_code)
    respond_to do |format|
      format.json {render json: field}
    end
  end

  private

  def add_pool_to_fq(solr_parameters, user_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << "pool:#{@pool.id}"
  end

  # Transforms a solr facet counts array into an array of hashes with :value and :count keys
  # @example
  #   hashify_facet_counts(["My Topic",20,"Other Topic",15])
  #   =>  [{value:"My Topic", count:20}, {value:"Other Topic", count:15}]
  def hashify_facet_counts(facet_counts)
    hashified_facet_counts = []
    facet_counts.each_with_index do |value, index|
      if (index %2 ==0) then
        hashified_facet_counts << {value:value, count:facet_counts[index+1]}
      end
    end
    hashified_facet_counts
  end

  # Set up minimal Blacklight configuration for SolrHelper to rely on
  def load_configuration
    @blacklight_config = Blacklight::Configuration.new
    @blacklight_config.configure do |config|
      ## Default parameters to send to solr for all search-like requests. See also SolrHelper#solr_search_params
      config.default_solr_params = {
          :qt => 'search',
          :fl => '*',
          :rows => 10
      }

    end
  end

  # Spoofing blacklight_config accessor
  def blacklight_config
    @blacklight_config
  end

  # Spoofing blacklight_solr accessor
  def blacklight_solr
    @solr ||=  RSolr.connect(blacklight_solr_config)
  end

  # Spoofing blacklight_solr_config accessor
  def blacklight_solr_config
    Blacklight.solr_config
  end
end
