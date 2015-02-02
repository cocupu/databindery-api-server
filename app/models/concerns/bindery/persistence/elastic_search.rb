module Bindery::Persistence::ElasticSearch
  extend ActiveSupport::Autoload
  autoload :QueryBuilder
  autoload :FilterSet
  def self.client(opts={})
    opts = {log: false}.merge(elasticsearch_config).merge(opts)
    @client ||= Elasticsearch::Client.new opts
  end

  def self.elasticsearch_file
    "#{::Rails.root.to_s}/config/elasticsearch.yml"
  end

  def self.elasticsearch_config
    @elasticsearch_config ||= begin
      raise "You are missing an elasticsearch configuration file: #{elasticsearch_file}." unless File.exists?(elasticsearch_file)

      begin
        @elasticsearch_erb = ERB.new(IO.read(elasticsearch_file)).result(binding)
      rescue Exception => e
        raise("#{elasticsearch_file} was found, but could not be parsed with ERB. \n#{$!.inspect}")
      end
      begin
        elasticsearch_config = YAML::load(@elasticsearch_erb)
      rescue StandardError => e
        raise("#{elasticsearch_file} was found, but could not be parsed.\n")
      end

      raise "The #{::Rails.env} environment settings were not found in the #{elasticsearch_file} config" unless elasticsearch_config[::Rails.env]
      elasticsearch_config[::Rails.env].symbolize_keys
    end
    @elasticsearch_config
  end

end