require 'rails_helper'

describe Node do
  let(:identity) { FactoryGirl.create :identity }
  let(:pool){ FactoryGirl.create :pool, :owner=>identity }
  let(:first_name_field) { FactoryGirl.create :first_name_field }
  let(:last_name_field) { FactoryGirl.create :last_name_field }
  let(:title_field) { FactoryGirl.create :title_field }
  let(:node)  { Node.new(model: model) }
  let(:model) do
    FactoryGirl.create(:model,
                       fields: [first_name_field,last_name_field],
                       label_field: last_name_field,
                       association_fields_attributes: [{name: 'authors', references: ref.id}])
  end
  let(:ref) do
    FactoryGirl.create(:model,
                       fields: [first_name_field, last_name_field, title_field],
                       label_field: last_name_field)
  end

  subject { node }

  it "creates a new version when it's changed" do
    subject.pool = pool
    subject.save!
    subject.update_attributes(:data=>{'boo'=>'bap'})
    all_versions = Node.where(persistent_id: subject.persistent_id).to_a
    all_versions.length.should == 2
  end

  it "copies on write (except id, parent_id and timestamps)" do
    subject.pool = pool
    subject.save!
    subject.attributes = {:data=>{'boo'=>'bap'}}
    new_subject = subject.update
    old_attributes = subject.attributes
    old_attributes.delete('id')
    old_attributes.delete('parent_id')
    old_attributes.delete('created_at')
    old_attributes.delete('updated_at')

    new_attributes = new_subject.attributes
    new_attributes.delete('id')
    new_attributes.delete('created_at')
    new_attributes.delete('updated_at')
    new_attributes.delete('parent_id').should == subject.id
    new_attributes.should == old_attributes
  end

  describe "version accessors" do
    let(:node) { Node.create!(model:model, pool:pool) }
    let(:updated_node) do
      node.attributes = {:data=>{'boo'=>'bap'}}
      node.update
    end
    before do
      updated_node
    end
    describe "versions" do
      it "gets all the node versions" do
        expect(Node.versions(subject.persistent_id)).to eq [updated_node, node]
        expect(node.versions).to eq [updated_node, node]
      end
    end
    describe "version_ids" do
      it "gets all the node version ids" do
        expect(Node.version_ids(subject.persistent_id)).to eq [updated_node.id, node.id]
        expect(node.version_ids).to eq [updated_node.id, node.id]
      end
    end
    describe "latest_version" do
      it "gets the latest version" do
        expect(Node.latest_version(subject.persistent_id)).to eq updated_node
        expect(node.latest_version).to eq(updated_node)
      end
    end
    describe "latest_version_id" do
      it "gets the latest version id" do
        expect(Node.latest_version_id(subject.persistent_id)).to eq updated_node.id
        expect(node.latest_version_id).to eq(updated_node.id)
      end
    end
  end

  it "should track who made changes" do
    identity1 = find_or_create_identity("bob")
    identity2 = find_or_create_identity("chinua")
    subject.pool = pool
    subject.save!
    subject.modified_by.should be_nil
    original = subject
    subject.update_attributes(:modified_by=>identity1, :data=>{'boo'=>'bap'})
    subject.modified_by.should == identity1
    v1 = subject.latest_version
    subject.update_attributes(:modified_by=>identity2, :data=>{'boo'=>'bappy'})
    subject.modified_by.should == identity2
    v2 = subject.latest_version
    Node.find(original.id).modified_by.should be_nil
    Node.find(v1.id).modified_by.should == identity1
    Node.find(v2.id).modified_by.should == identity2
    identity1.contributions.should == [v1]
    identity2.contributions.should == [v2]
    subject.update_attributes(:data=>{'boo'=>'lollipop'})
    subject.latest_version.modified_by.should be_nil
  end

  it "should reset modified_by whenever attributes change" do
    identity = find_or_create_identity("bob")
    identity2 = find_or_create_identity("chinua")
    subject.modified_by = identity
    subject.modified_by.should == identity
    subject.attributes = {:data=>{'boo'=>'bap'}}
    subject.modified_by.should be_nil
    subject.attributes = {modified_by: identity2, :data=>{'boo'=>'bapper'}}
    subject.modified_by.should == identity2
    subject.update_attributes(:data=>{'boo'=>'bapperest'})
    subject.modified_by.should be_nil
  end


end
