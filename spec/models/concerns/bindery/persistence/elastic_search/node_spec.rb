require  'rails_helper'

describe Bindery::Persistence::ElasticSearch::Node do

  subject{ ::Node.new }
  let(:elasticsearch) { Bindery::Persistence::ElasticSearch.client }
  let(:identity) { FactoryGirl.create :identity }
  let(:pool){ FactoryGirl.create :pool, :owner=>identity }
  let(:first_name_field) { FactoryGirl.create :first_name_field }
  let(:last_name_field) { FactoryGirl.create :last_name_field }
  let(:title_field) { FactoryGirl.create :title_field }

  let(:model) do
    FactoryGirl.create(:model,
                       fields: [first_name_field, last_name_field, title_field],
                       label_field: last_name_field, association_fields_attributes: [{name: 'authors', references: ref.id}])
  end
  let(:ref) do
    FactoryGirl.create(:model,
                       fields: [first_name_field, last_name_field, title_field],
                       label_field: last_name_field)
  end

  before do
    subject.model = model
  end

  describe "integration", sidekiq: :inline, elasticsearch: true do
    it "indexes the record in elasticsearch on create, deletes it from elasticsearch on destroy" do
      node = FactoryGirl.create(:node, model:model, pool:pool, data:{"first_name"=>"Buzz", "last_name"=>"Aldrin"})
      sleep 1
      result = Bindery::Persistence::ElasticSearch.client.search index: pool.to_param, q:"id:#{node.persistent_id}"
      expect(result["hits"]["total"]).to eq 1
      index_document = node.__elasticsearch__.get
      expect(index_document["_source"]).to eq({"first_name"=>"Buzz", "last_name"=>"Aldrin", "id"=>node.persistent_id, "_bindery_title"=>"Aldrin", "_bindery_node_version"=>node.id, "_bindery_model_name"=>node.model.name, "_bindery_pool"=>node.pool_id, "_bindery_format"=>"Node", "_bindery_model"=>node.model_id})
      node.destroy
      sleep 1
      result = Bindery::Persistence::ElasticSearch.client.search index: pool.to_param, q:"id:#{node.persistent_id}"
      expect(result["hits"]["total"]).to eq 0
    end
    it "overwrites data values in elasticsearch document (rather than duplicating field values on update)" do
      node = FactoryGirl.create(:node, model:model, pool:pool)
      node.data["first_name"] = "Chinua"
      node.data["last_name"] = "Achebe"
      node.save
      sleep 1
      index_document = node.__elasticsearch__.get(fields:["first_name", "last_name", "_source"])
      expect(index_document["fields"]["first_name"]).to eq(["Chinua"])
      expect(index_document["fields"]["last_name"]).to eq(["Achebe"])
      expect(index_document["_source"]).to eq({"first_name"=>"Chinua", "last_name"=>"Achebe", "id"=>node.persistent_id, "_bindery_title"=>"Achebe", "_bindery_node_version"=>node.id+1, "_bindery_model_name"=>node.model.name, "_bindery_pool"=>node.pool_id, "_bindery_format"=>"Node", "_bindery_model"=>node.model_id})
    end
  end

  describe "create" do
    it "schedules an asynchronous indexing job" do
      expect(Bindery::Persistence::ElasticSearch::Node::NodeIndexer).to receive(:perform_async)
      FactoryGirl.create(:node)
    end
  end

  describe "save" do
    it "uses an asynchronous job to index its data into elasticsearch" do
      node = FactoryGirl.create(:node)
      node.data["foo"] ="bar"
      expect(Bindery::Persistence::ElasticSearch::Node::NodeIndexer).to receive(:perform_async).once
      node.save
    end
  end

  describe "destroy" do
    it "uses an asynchronous job to delete itself from elasticsearch" do
      expect(Bindery::Persistence::ElasticSearch::Node::NodeDestroyer).to receive(:perform_async)
      subject.save
      subject.destroy
    end
  end

  describe "as_elasticsearch" do

    describe "with data" do
      before do
        subject.pool = pool
        subject.data = {'f1'=>'good', first_name_field.to_param => 'Heathcliff', last_name_field.to_param => 'Huxtable', title_field.to_param=>'Dr.'}
      end

      it "should produce a hash with correct field names" do
        # f1 is not defined as a field on the model, so it's not indexed.
        expect(subject.as_elasticsearch).to eq subject.data.merge( {'id'=>subject.persistent_id, '_bindery_title'=>subject.title,'_bindery_node_version'=>subject.id, '_bindery_model_name' =>subject.model.name, '_bindery_pool' => pool.id, '_bindery_format'=>'Node', '_bindery_model'=>subject.model.id} )
      end
    end

    describe "with associations" do
      let(:full_name_field) {Field.create("name"=>"Name", "type"=>"TextField", "uri"=>"dc:description", "code"=>"full_name")}
      let(:book_title_field) {Field.create("code" => "book_title", "name"=>"Book title")}

      before do
        @author_model = FactoryGirl.create(:model, name: 'Author', label_field: full_name_field,
                                           fields: [full_name_field],
                                           owner: identity)
        @author1 = FactoryGirl.create(:node, model: @author_model, pool: pool, data: {full_name_field.to_param => 'Agatha Christie'})
        @author2 = FactoryGirl.create(:node, model: @author_model, pool: pool, data: {full_name_field.to_param => 'Raymond Chandler'})
        @contributing_authors_association = OrderedListAssociation.create(:name=>'Contributing Authors', :code=>'contributing_authors', :references=>@author_model.id)
        subject.model = FactoryGirl.create(:model, name: 'Book', label_field: book_title_field, owner: identity,
                                           fields: [book_title_field],
                                           association_fields: [@contributing_authors_association])
        subject.data = {book_title_field.to_param=>'How to write mysteries',@contributing_authors_association.to_param=>[@author1.persistent_id, @author2.persistent_id]}
        subject.pool = pool
        subject.save!
      end
      it "should index the properties of the child associations and add their persistent ids to a bindery__associations facet field" do
        expect(subject.as_elasticsearch).to eq ( {'id'=>subject.persistent_id, '_bindery_node_version'=>subject.id, '_bindery_model_name' =>subject.model.name, '_bindery_pool' => pool.id,
                                   '_bindery_format'=>'Node', '_bindery_model'=>subject.model.id,
                                   'contributing_authors'=>['Agatha Christie', 'Raymond Chandler'],
                                   'contributing_authors__full_name'=>['Agatha Christie', 'Raymond Chandler'],
                                   "book_title" => "How to write mysteries",
                                   "_bindery_title" => "How to write mysteries",
                                   "_bindery__associations" => [@author1.persistent_id, @author2.persistent_id]
        } )
      end
    end
  end
end
