require 'rails_helper'

describe Node do
  let(:identity) { FactoryGirl.create :identity }
  let(:pool){ FactoryGirl.create :pool, :owner=>identity }
  let(:first_name_field) { FactoryGirl.create :first_name_field }
  let(:last_name_field) { FactoryGirl.create :last_name_field }
  let(:title_field) { FactoryGirl.create :title_field }
  let(:model) do
    FactoryGirl.create(:model,
                       fields: [first_name_field, last_name_field, title_field],
                       label_field: last_name_field,
                       association_fields_attributes: [{name: 'authors', references: ref.id}])
  end
  let(:ref) do
    FactoryGirl.create(:model,
                       fields: [first_name_field, last_name_field, title_field],
                       label_field: last_name_field)
  end

  before do
    subject.model = model
  end

  it "should have a binding" do
    subject.binding = '0B4oXai2d4yz6eENDUVJpQ1NkV3M'
    subject.binding.should == '0B4oXai2d4yz6eENDUVJpQ1NkV3M'
  end

  describe "files setter and getter" do
    before do
      @file1 = FactoryGirl.create(:node, model: Model.file_entity, pool: pool)
      @file2 = FactoryGirl.create(:node, model: Model.file_entity, pool: pool)
      @file3 = FactoryGirl.create(:node, model: Model.file_entity, pool: pool)
    end
    it "should match with file_ids array and should operate on FileEntity nodes" do
      subject.files.should be_empty
      subject.send(:file_ids).should be_empty
      subject.files << @file1
      subject.files << @file2
      subject.send(:file_ids).should == [@file1.persistent_id, @file2.persistent_id]
      subject.files.should == [@file1, @file2]
      subject.files.unshift(@file3)
      subject.files.should == [@file3, @file1, @file2]
      subject.send(:file_ids).should == [@file3.persistent_id, @file1.persistent_id, @file2.persistent_id]
      subject.associations["files"].should == subject.send(:file_ids)
    end
  end
  describe "attaching a file" do
    before do
      config = YAML.load_file(Rails.root + 'config/s3.yml')[Rails.env]
      @s3 = FactoryGirl.create(:s3_connection, config.merge(pool: pool))
    end
    it "should store a list of attached files" do
      subject.files.size.should == 0
      subject.pool = pool
      stub_ul = File.open(fixture_path + '/images/rails.png')
      stub_ul.stub(:mime_type => 'image/png')
      subject.attach_file('my_file.png', stub_ul)
      subject.files.size.should == 1
      file_node = Node.latest_version(subject.files.first.persistent_id)
      file_node.file_name.should == 'my_file.png'
      file_node.content.should == File.open(fixture_path + '/images/rails.png', "rb").read
    end
  end

end
