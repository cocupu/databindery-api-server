require 'elasticsearch/extensions/test/cluster'

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
