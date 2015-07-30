config = YAML.load_file(Rails.root + 'config/aws.yml')[Rails.env]
raise "Unable to init aws" unless config.is_a? Hash
AWS.config(config)

