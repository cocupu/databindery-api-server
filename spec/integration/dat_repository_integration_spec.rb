require 'rails_helper'

describe Bindery::Persistence::Dat::Repository, elasticsearch: true, sidekiq: :inline do
  let(:pool) { FactoryGirl.create(:dat_backed_pool) }
  let(:sample_repo) { setup_sample_repo }

  describe 'indexing' do
    it 'indexes data from dat into elasticsearch' do
      sample_repo
      puts "[integration] indexing dat content into Elasticsearch at #{sample_repo.pool.to_param}"
      sample_repo.index()
      sleep 1
      expect(pool.models.count).to eq 3
      query_all_result, query_all_document_list = pool.search(q:'*')
      expect(query_all_result['hits']['total']).to eq 182
      # TODO: query by type and check the results
      # for now, pick a random document and test that it has the characteristics of any of the models.
      es_document = query_all_document_list.first
      expect(['hail', 'proteins', 'plants']).to include es_document['_type']
      expect(['Hail', 'Proteins', 'Plants']).to include es_document['_source']['_bindery_model_name']
      expect(pool.model_ids).to include es_document['_source']['_bindery_model']
    end
  end

  def setup_sample_repo
    sample_repo_path = File.expand_path('tmp/dat/sample')
    sample_repo = described_class.new(pool: pool, dir: sample_repo_path)
    if sample_repo.is_dat_repository? && sample_repo.datasets == ["proteins", "plants", "hail"]
      puts "[integration] using the existing dat repo at #{sample_repo.dir}"
    else
      puts "[integration] creating sample dat repo at #{sample_repo.dir}"
      init_and_import_into(sample_repo)
      puts "[integration] created sample repo with datasets #{sample_repo.datasets}"
    end
    sample_repo
  end

  def init_and_import_into(repository)
    FileUtils.rm_rf(repository.dir)
    repository.init
    repository.import(dataset:'hail', file: fixture_file_path('data/small_datasets/hail-2014.csv'), key:'ZTIME')
    repository.import(dataset:'proteins', file: fixture_file_path('data/small_datasets/1pqx-ATOMS.csv'), key:'serial')
    repository.import(dataset:'plants', file: fixture_file_path('data/small_datasets/plantlst.csv'), key:'Symbol')
    repository
  end
end