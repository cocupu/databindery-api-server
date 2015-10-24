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
  let(:pool_with_model) do
    p = FactoryGirl.create(:dat_backed_pool, owner: owner)
    p.models.create(code:'mollusks', name:'Mollusks')
    p
  end

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
    let(:created_index_name) { 'anIndex' }
    let(:post_params) { { pool_id: pool }}
    subject { post :create, post_params }

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
        let(:pool) { pool_with_model }
        # POST /pools/3/indices
        it 'creates a new index and writes the pool\'s models into it as mappings' do
          expect(pool.__elasticsearch__).to receive(:create_index).with(index_name: nil).and_return(created_index_name)
          pool.models.each do |model|
            expect(model.__elasticsearch__).to receive(:save).with(index_name: created_index_name)
          end
          subject
        end
      end

      context 'with a source specified' do
        let(:post_params) { { pool_id: pool, source: :dat }}
        # POST /pools/3/indices source: :dat
        it 'creates a new index and indexes the content from that source' do
          expect(pool.__elasticsearch__).to receive(:create_index).with(index_name: nil).and_return(created_index_name)
          expect(pool).to receive(:update_index).with(index_name: created_index_name, :source=>"dat")
          subject
        end
      end

      context 'setting the alias' do
        let(:post_params) { { pool_id: pool, alias: true }}
        # POST /pools/3/indices alias: 'live', source: {dat: {from:'commitHash1', to:'commitHash2'}}
        it 'builds a new index then points the alias at it' do
          # this lets you 'rebuild' the live index (build a new index
          # then swap it in as the live index) with a single request
          expect(pool.__elasticsearch__).to receive(:create_index).with(index_name: nil).and_return(created_index_name)
          expect(pool.__elasticsearch__).to receive(:set_alias).with(created_index_name).and_return(created_index_name)
          subject
        end
      end

      context 'skipping models' do
        let(:pool) { pool_with_model }
        # This is mainly useful if you want to allow the index to auto-detect data types
        let(:post_params) { { pool_id: pool, write_models: false }}

        # POST /pools/3/indices write_models: false, source: :dat
        it 'creates a new index and writes data to it without persisting models' do
          expect(pool.__elasticsearch__).to receive(:create_index).with(index_name: nil).and_return(created_index_name)
          pool.models.each do |model|
            expect(model.__elasticsearch__).to_not receive(:save)
          end
          subject
        end
      end
    end


  end

  describe 'show' do
    # GET /pools/3/indices/8_2015-10-19_15:10:15
    subject { get :show, pool_id: pool, id: index_name }
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

      context 'when the pool has an index by that name' do
        before do
          expect(pool.__elasticsearch__).to receive(:require_index_to_be_in_pool!).with(index_name).and_return(nil)
        end
        it 'gets/shows info about an index' do
          expect(pool.__elasticsearch__).to receive(:get_index).with(index_name).and_return('the response')
          expect(response.body).to eq('the response')
        end
      end

      context 'when the pool doesn\'t have an index by that name' do
        before do
          expect(pool.__elasticsearch__).to receive(:require_index_to_be_in_pool!).with(index_name).and_raise(ArgumentError, 'the error message')
        end
        it 'returns unprocessable_entity' do
          expect(response).to respond_unprocessable_entity(description: 'the error message')
        end
      end

      context 'when id is "live"' do
        # get/show info about current default/'live' index
        # GET /pools/3/indices/live
        let(:index_name) { 'live' }
        it 'returns info for the index that the pool\'s main alias points to' do
          expect(pool.__elasticsearch__).to receive(:get_index).with(pool.to_param).and_return('the response')
          expect(response.body).to eq('the response')
        end
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
        subject { put :update, pool_id: pool, id: 'live' }
        # PUT /pools/3/indices/live source: :dat
        it 'updates the contents of the pool\'s current main aliased index' do
          expect(pool.dat).to receive(:index).with(index_name: pool.to_param)
          expect(response).to respond_success
        end

        context 'and an index_name is also provided' do
          let(:new_index_name) { '8_2014-08-30_15:10:15' }
          subject { put :update, pool_id: pool, id: 'live', index_name: new_index_name }
          before do
            # the check we're relying on is run within pool.dat.index()
            # so allowing it to run but making it process zero datasets
            allow(pool.dat).to receive(:datasets).and_return([])
          end
          # alias 'live' to a different index
          # PUT /pools/3/indices/live index_name: '8_2015-10-19_15:10:15'
          context 'when the new index_name is valid' do
            before do
              expect(pool.__elasticsearch__).to receive(:require_index_to_be_in_pool!).and_return(nil)
            end
            it 'updates the pool\'s main alias' do
              expect(pool.__elasticsearch__).to receive(:set_alias).with(new_index_name)
              expect(response).to be_successful
            end
          end
          context 'when the new index_name is not valid' do
            before do
              expect(pool.__elasticsearch__).to receive(:require_index_to_be_in_pool!).and_raise(ArgumentError, "Message - index not in pool.")
            end
            it 'does not update the alias' do
              expect(pool.__elasticsearch__).to_not receive(:set_alias)
              expect(response).to respond_unprocessable_entity(description: "Message - index not in pool.")
            end
          end
        end
      end
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
