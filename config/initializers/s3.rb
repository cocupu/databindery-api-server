config = YAML.load_file(Rails.root + 'config/s3.yml')[Rails.env]
raise "Unable init s3" unless config.is_a? Hash
AWS.config(config)

