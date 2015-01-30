require 'rails_helper'

describe Node do
  let(:identity) { FactoryGirl.create :identity }
  let(:pool){ FactoryGirl.create :pool, :owner=>identity }
  let(:full_name_field) { FactoryGirl.create :full_name_field }
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

  describe "#find_by_identifier" do
    before do
      @node = Bindery::Spreadsheet.create(pool: pool, model: Model.file_entity)
    end
    it "should accept Node persistent_ids" do
      Node.should_receive(:find_by_persistent_id).with(@node.persistent_id).and_return(@node)
      Node.find_by_identifier(@node.persistent_id).should == @node
    end
    it "should accept Node ids" do
      Node.should_receive(:find).with(@node.id).and_return(@node)
      Node.find_by_identifier(@node.id).should == @node
    end
  end

  describe "find_by_persistent_id" do
    it "should always return the latest version" do
      subject.pool = pool
      subject.save!
      subject.attributes = {:data=>{'boo'=>'bap'}}
      new_subject = subject.update
      Node.latest_version(subject.persistent_id).should == Node.find_by_persistent_id(subject.persistent_id)
    end
  end

  describe "reify_association" do
    it "should reify_associations" do
      author1 = Node.create!(pool:pool, model:ref)
      author2 = Node.create!(pool:pool, model:ref)
      subject.data["32"] = [author1.persistent_id, author2.persistent_id]
      subject.reify_association("32").should == [author1, author2]
      subject.reify_association(32).should == [author1, author2]
    end
  end

  describe "with associations" do
    before do
      @author_model = FactoryGirl.create(:model, name: 'Author', label_field: full_name_field,
                                         fields: [full_name_field],
                                         owner: identity)
      @author1 = FactoryGirl.create(:node, model: @author_model, pool: pool, data: {'full_name' => 'Agatha Christie'})
      @author2 = FactoryGirl.create(:node, model: @author_model, pool: pool, data: {'full_name' => 'Raymond Chandler'})
      @contributing_authors_association = OrderedListAssociation.create(:name=>'Contributing Authors', :code=>'contributing_authors', :references=>@author_model.id)
      subject.model = FactoryGirl.create(:model, name: 'Book', label_field: title_field, owner: identity,
                                         fields:[title_field],
                                         association_fields: [@contributing_authors_association])
      subject.data = {'book_title'=>'How to write mysteries', @contributing_authors_association.to_param => [@author1.persistent_id, @author2.persistent_id]}
      subject.pool = pool
      subject.save!
    end

    describe "find_association" do
      it "should return all of the nodes pointed to by a particular association" do
        nodes = subject.find_association(@contributing_authors_association.id)
        nodes.length.should == 2
        nodes.should include(@author1)
        nodes.should include(@author2)
      end
      it "should return an nil if association is nil or a string" do
        subject.find_association("foo").should be_nil
        subject.associations["foo"] = ""
        subject.find_association("foo").should be_nil
      end
    end
    describe "incoming" do
      it "should return all of the nodes pointing to the current object" do
        @author1.incoming.should == [subject]
      end
    end
  end

end

