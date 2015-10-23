class DatRow

  attr_accessor :row_json, :id, :pool, :model, :data, :persistent_id, :row_format

  # These callbacks are used by some of the Bindery::Node modules
  # define them before including the modules.

  def self.before_save(procs=[], opts={})
    # do nothing, for now.
  end

  def self.after_create(procs=[], opts={})
    # do nothing, for now.
  end

  def self.after_destroy(procs=[], opts={})
    # do nothing, for now.
  end

  def self.after_find(procs=[], opts={})
    # do nothing, for now.
  end

  ## Most of the Action is in the Bindery::Node module and its submodules
  include Bindery::Node

  def initialize(opts={})
    @row_json = self.class.parse_row_json(opts[:row_json])
    @pool = opts[:pool]
    @model = opts[:model]
    @data = opts[:data]
    @persistent_id = opts[:persistent_id]
    @row_format = opts[:row_format]
  end

  def pool_id
    pool.id
  end

  def model_id
    model.id
  end

  # Render a bulk action for updating elasticsearch with this row's contents
  # @option [String] index_name to populate the _index value (defaults to using the index name for the row's pool)
  # @option [String] model_name to populate the _type value (defaults to using the code from the row's model)
  # @example
  #   parsed_row.as_elasticsearch_bulk_action(index_name:'foo_index')
  #   => {:index=>{:_index=>"foo_index", :_type=>"proteins", :_id=>"128", :data=>"esdoc1"}}, {:index=>{:_index=>"foo_index", :_type=>"plants", :_id=>"ABMA", :data=>"esdoc2"}}
  def as_elasticsearch_bulk_action(index_name: nil, model_name: nil, action: :index)
    index_name ||= pool.to_param
    model_name ||= model.code
    { action =>  { _index: index_name, _type: model_name, _id: persistent_id, data: self.as_elasticsearch } }
  end

  # Parse dat json output and return a DatRow object
  # Recognizes 2 formats automatically and parses their data as a DatRow:
  #   * :export (output from running `dat export --full`)
  #   * :diff (output from running `dat diff`)
  # The original data is stored in the +row_json+ attribute and the original format is recorded in the +row_format+ attribute.
  # @param [Hash] row JSON for the row
  # @option [String] pool
  # @option [String] model
  def self.parse(row, pool: nil, model: nil)
    # raise ArgumentError, 'row_format must be either :diff or :export' unless [:diff, :export].include?(row_format)
    row_json = parse_row_json(row)
    if row_json.has_key?('forks') && row_json.has_key?('versions')
      row_format = :diff
    elsif row_json.has_key?('value')
      row_format = :export
    else
      raise ArgumentError, 'The row you submitted is not a row from a dat diff or dat export.  You submitted #{row}'
    end
    instance = self.new(row_json: row_json, persistent_id: row['key'], pool: pool, model: model, row_format: row_format)
    instance.persistent_id = row_json['key']
    case row_format
      when :diff
        instance.id = row_json['forks'].last
        instance.model ||= row_json['dataset']
        instance.data = row_json['versions'].last['value']
      when :export
        instance.id = row_json['version']
        instance.data = row_json['value']
      else
        instance.data = row_json
    end
    instance
  end

  def self.parse_row_json(row_json)
    if row_json.instance_of?(Hash)
      row_json
    else
      JSON.parse(row_json)
    end
  end


end
