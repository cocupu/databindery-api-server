begin
  require 'elasticsearch/extensions/test/cluster'
  require 'foo'

  namespace :elastic_search do
    namespace :testcluster do
      desc 'Start the elasticsearch test cluster'
      task :start do
        Elasticsearch::Extensions::Test::Cluster.start
      end

      desc 'Stop the elasticsearch test cluster'
      task :stop do
        Elasticsearch::Extensions::Test::Cluster.stop
      end
    end

  end
rescue LoadError
  puts "WARN: could not load 'elasticsearch/extensions/test/cluster' so skipping the elasticsearch:testcluster rake tasks."
end

