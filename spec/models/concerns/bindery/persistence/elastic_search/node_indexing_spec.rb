require 'rails_helper'

describe Bindery::Persistence::ElasticSearch::Node do
  subject {
    node = ::Node.new
    # node.extend Bindery::Persistence::ElasticSearch::Node
    node.model = model
    node
  }
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
    # The module is already included in Bindery::Node, so don't need to add it to the Class here
    # subject.extend Bindery::Persistence::ElasticSearch::Node
  end

  it "aliases as_index_document, attributes_for_index, associations_for_index and field_name_for_index to elasticsearch implementations" do
    expect(subject).to receive(:as_elasticsearch)
    subject.as_index_document
    expect(subject).to receive(:data_as_elasticsearch)
    subject.attributes_for_index
    expect(subject).to receive(:associations_as_elasticsearch)
    subject.associations_for_index
    expect(Node).to receive(:field_name_for_elasticsearch)
    Node.field_name_for_index("foo")
  end

  describe "data_as_elasticsearch" do
    it "should return the part of the solr document that is just the model attributes" do
      subject.data = {first_name_field.to_param=>'Nina', last_name_field.to_param=>'Simone', title_field.to_param=>'Ms.'}
      expect(subject.data_as_elasticsearch).to eq({"first_name"=>"Nina", "first_name"=>"Nina", "last_name"=>"Simone", "last_name"=>"Simone", 'title'=>"Ms."})
    end
  end

  describe "field_name_for_elasticsearch" do
    it "should remove whitespaces" do
      Node.field_name_for_elasticsearch("one two\t\tthree").should == "one_two_three"
    end
    it "should use the prefix" do
      Node.field_name_for_elasticsearch("first name", :prefix=>'related_object__', :type=>'facet').should == "related_object__first_name"
    end
  end

  describe "with data" do
    before do
      subject.pool = pool
      subject.data = {'f1'=>'good', first_name_field.to_param => 'Heathcliff', last_name_field.to_param => 'Huxtable', title_field.to_param=>'Dr.'}
    end

    it "should produce a solr document with correct field names, INCLUDING node data that are not defined in the model" do
      # f1 is not defined as a field on the model, so it's not indexed.
      subject.as_elasticsearch.should == {'id'=>subject.persistent_id, '_bindery_node_version'=>subject.id, '_bindery_model_name' =>subject.model.name, '_bindery_pool' => pool.id, '_bindery_format'=>'Node', '_bindery_model'=>subject.model.id, '_bindery_title'=>'Huxtable', 'first_name'=>'Heathcliff', 'first_name'=>'Heathcliff', 'last_name'=>'Huxtable', 'last_name'=>'Huxtable', 'title' => 'Dr.', "f1" => "good"}
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
    it "should index the properties of the child associations and add their persistent ids to an _bindery__associations_facet field" do
      subject.as_elasticsearch.should == {'id'=>subject.persistent_id, '_bindery_node_version'=>subject.id, '_bindery_model_name' =>subject.model.name, '_bindery_pool' => pool.id,
                                 '_bindery_format'=>'Node', '_bindery_model'=>subject.model.id,
                                 'contributing_authors'=>['Agatha Christie', 'Raymond Chandler'],
                                 'contributing_authors'=>['Agatha Christie', 'Raymond Chandler'],
                                 'contributing_authors__full_name'=>['Agatha Christie', 'Raymond Chandler'],
                                 'contributing_authors__full_name'=>['Agatha Christie', 'Raymond Chandler'],
                                 "book_title" => "How to write mysteries",
                                 "book_title" => "How to write mysteries",
                                 '_bindery_title' => "How to write mysteries",
                                 "_bindery__associations" => [@author1.persistent_id, @author2.persistent_id]
      }
    end
  end

end
