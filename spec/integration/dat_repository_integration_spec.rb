require 'rails_helper'

describe Api::V1::PoolIndicesController, type: :request, elasticsearch: true, sidekiq: :inline do
  let(:sample_dat_repo) { setup_sample_dat_repo }
  let(:path_to_sample_dat) { 'tmp/dat/sample' }
  let(:pool) { FactoryGirl.create(:dat_backed_pool, dat_location: path_to_sample_dat) }
  let(:login_credential) { pool.owner.login_credential }

  describe 'indexing' do
    it 'indexes data from dat into elasticsearch' do
      puts "[integration] indexing dat content into Elasticsearch at #{sample_dat_repo.pool.to_param}"
      env ={ 'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(login_credential.email, login_credential.password) }
      put "/api/v1/pools/#{pool.id}/indices/live", {}, env
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

  def setup_sample_dat_repo
    sample_dat_repo_path = File.expand_path(path_to_sample_dat)
    sample_dat_repo = Bindery::Persistence::Dat::Repository.new(pool: pool, dir: sample_dat_repo_path)
    if sample_dat_repo.is_dat_repository? && sample_dat_repo.datasets == ["proteins", "plants", "hail"]
      puts "[integration] using the existing dat repo at #{sample_dat_repo.dir}"
    else
      puts "[integration] creating sample dat repo at #{sample_dat_repo.dir}"
      init_and_import_into(sample_dat_repo)
      puts "[integration] created sample repo with datasets #{sample_dat_repo.datasets}"
    end
    sample_dat_repo
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