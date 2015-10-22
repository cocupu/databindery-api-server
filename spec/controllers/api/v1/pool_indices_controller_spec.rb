require 'rails_helper'

describe Api::V1::PoolIndicesController do
  let(:owner) { FactoryGirl.create(:identity) }
  let(:reader) do
    reader = FactoryGirl.create(:identity)
    AccessControl.create!(:pool=>pool, :identity=>reader, :access=>'READ')
    reader
  end
  let(:editor) do
    editor = FactoryGirl.create(:identity)
    AccessControl.create!(:pool=>pool, :identity=>editor, :access=>'EDIT')
    editor
  end
  let(:pool) { FactoryGirl.create(:dat_backed_pool, owner: owner)}
  let(:index_name) { '8_2015-10-19_15:10:15' }
  let(:aliases) { {"3149_2015-10-21_17:10:43"=>{"aliases"=>{"3149-all"=>{}}}}}
  let(:elasticsearch_adapter) { double('elasticsearch') }
  let(:response) { subject }

  before do
    allow(Pool).to receive(:find).with(pool.id.to_s).and_return(pool)
    allow(pool).to receive(:__elasticsearch__).and_return(elasticsearch_adapter)
  end

  # TODO: configure models based on the mappings in an index
  # POST /pools/3/models load_from_index: true

  describe 'index' do
    subject { get :index, pool_id: pool }

    describe "when not logged on" do
      it "requires authentication" do
        expect(response).to respond_unauthorized
      end
    end

    describe "when not a reader on the pool" do
      before do
        sign_in FactoryGirl.create(:identity).login_credential
      end
      it "forbids access" do
        expect(response).to respond_forbidden
      end
    end

    describe "when logged on with read access to the pool" do
      before do
        sign_in reader.login_credential
      end

      # GET /pools/3/indices
      it 'lists all of the pool\'s indices' do
        expect(elasticsearch_adapter).to receive(:get_aliases).with(scope: :all).and_return(aliases)
        expect(response.body).to eq aliases.keys.to_json
      end
    end


  end

  describe 'create' do
    subject { post :create, pool_id: pool }

    describe "when not logged on" do
      it "requires authentication" do
        expect(response).to respond_unauthorized
      end
    end

    describe "when not an editor on the pool" do
      before do
        sign_in reader.login_credential
      end
      it "forbids access" do
        expect(response).to respond_forbidden
      end
    end

    describe "when logged on with edit access to the pool" do
      before do
        sign_in editor.login_credential
      end
      # POST /pools/3/indices
      it 'creates a new index and writes the pool\'s models into it as mappings'

      context 'with a source specified' do
        # POST /pools/3/indices source: :dat
        it 'creates a new index and indexes the content from that source'
      end

      context 'with an alias specified' do
        # POST /pools/3/indices alias: 'live', source: {dat: {from:'commitHash1', to:'commitHash2'}}
        it 'builds a new index then points the alias at it'
        it 'translates "live" index as the pool\'s default index'
        # this lets you 'rebuild' the live index (build a new index
        # then swap it in as the live index) with a single request
      end

      context 'skipping models' do
        # This is mainly useful if you want to allow the index to auto-detect data types

        # POST /pools/3/indices write_models: false, source: :dat
        it 'creates a new index and writes data to it without persisting models'
      end
    end


  end

  describe 'show' do
    subject { get :show, pool_id: pool, id:'8_2015-10-19_15:10:15' }
    describe "when not logged on" do
      it "requires authentication" do
        expect(response).to respond_unauthorized
      end
    end

    describe "when not a reader on the pool" do
      before do
        sign_in FactoryGirl.create(:identity).login_credential
      end
      it "forbids access" do
        expect(response).to respond_forbidden
      end
    end

    describe "when logged on with read access to the pool" do
      before do
        sign_in reader.login_credential
      end
      # GET /pools/3/indices/8_2015-10-19_15:10:15
      it 'gets/shows info about an index'

      context 'when index_name is "live"' do
        let(:index_name) { 'live' }
        # get/show info about current default/'live' index
        # GET /pools/3/indices/live
        it 'returns to the index that the pool\'s main alias points to'
      end
    end
  end

  describe 'update' do
    subject { put :update, pool_id: pool, id: index_name }

    describe "when not logged on" do
      it "requires authentication" do
        expect(response).to respond_unauthorized
      end
    end

    describe "when not an editor on the pool" do
      before do
        sign_in reader.login_credential
      end
      it "forbids access" do
        expect(response).to respond_forbidden
      end
    end

    describe "when logged on with edit access to the pool" do
      before do
        sign_in editor.login_credential
      end
      context 'by default' do
        subject { put :update, pool_id: pool, id: index_name }
        # PUT /pools/3/indices/8_2015-10-19_15:10:15 source: :dat
        it 'indexes everything from dat (full export)' do
          expect(pool.dat).to receive(:index).with(index_name: index_name)
          expect(response).to respond_success
        end
      end
      context 'from dat' do
        subject { put :update, pool_id: pool, id: index_name, source: :dat }

        # PUT /pools/3/indices/8_2015-10-19_15:10:15 source: :dat
        it 'indexes everything from dat (full export)' do
          expect(pool.dat).to receive(:index).with(index_name: index_name)
          expect(response).to respond_success
        end

        context 'with from: and to: specified' do
          subject { put :update, pool_id: pool, id: index_name, source: { dat: { from:'commitHash1', to:'commitHash2'} } }

          # PUT /pools/3/indices/8_2015-10-19_15:10:15 source: {dat: {from:'commitHash1', to:'commitHash2'}}
          it 'updates index with the latest changes from dat (dat diff)' do
            expect(pool.dat).to receive(:index).with(index_name: index_name, from: 'commitHash1', to: 'commitHash2')
            expect(response).to respond_success
          end
        end
      end

      context 'when id is "live"' do
        let(:index_name) { 'live' }
        # PUT /pools/3/indices/live source: :dat
        it 'updates the pool\'s current main aliased index' do
          expect(pool.dat).to receive(:index).with(index_name: pool.to_param)
          expect(response).to respond_success
        end

        context 'replacing "live" index' do
          let(:new_index_name) { '8_2014-08-30_15:10:15' }
          subject { put :update, pool_id: pool, id: 'live', index_name: new_index_name }

          # alias 'live' to a different index
          # PUT /pools/3/indices/live index_name: '8_2015-10-19_15:10:15'
          context 'when the new index_name is valid' do
            before do
              expect(pool).to receive(:indexes).and_return([new_index_name])
            end
            it 'updates the pool\'s main alias'
          end
          context 'when the new index_name is not valid' do
            before do
              expect(pool).to receive(:indexes).and_return([])
            end
            it 'does not update the alias'
          end
        end
      end


      # context 'writing only models to an index' do
      #   # PUT /pools/3/indices/8_2015-10-19_15:10:15 write_models: true
      #   it 'writes the pool\'s models to the index as mappings'
      # end
    end

  end

  describe 'destroy' do
    subject { delete :destroy, pool_id: pool, id: index_name }

    describe "when not logged on" do
      it "requires authentication" do
        expect(response).to respond_unauthorized
      end
    end

    describe "when not an editor on the pool" do
      before do
        sign_in reader.login_credential
      end
      it "forbids access" do
        expect(response).to respond_forbidden
      end
    end

    describe "when logged on with edit access to the pool" do
      before do
        sign_in editor.login_credential
      end

      # destroy index
      # DELETE /pools/3/indices/8_2015-10-19_15:10:15
      it 'destroys the index' do
        expect(elasticsearch_adapter).to receive(:delete_index).with(index_name)
        expect(response).to respond_deleted
      end
    end

  end

end
