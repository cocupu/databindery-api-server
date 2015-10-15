require 'rails_helper'

describe Bindery::Spreadsheet do

  it "should belong to a Pool and have a Model" do
    subject.should_not be_valid
    subject.errors.full_messages.should == ["Pool can't be blank"]
    expect(subject.model).to eq Model.file_entity
    subject.pool = SqlBackedPool.create
    expect(subject).to be_valid
  end

  describe "file binding lookups" do
    before do
      @version1 = FactoryGirl.create(:node, binding:"bindingXYZ", model: Model.file_entity)
      @version2 = FactoryGirl.create(:node, binding:"binding1", persistent_id:@version1.persistent_id, model: Model.file_entity)
      @version3 = FactoryGirl.create(:node, binding:"binding1", persistent_id:@version1.persistent_id, model: Model.file_entity)
      @version4 = FactoryGirl.create(:node, binding:"binding1", persistent_id:@version1.persistent_id, model: Model.file_entity)
    end
    describe "#version_with_latest_file_binding" do
      it "should return the node where the latest file binding was set" do
        result = Bindery::Spreadsheet.version_with_latest_file_binding(@version4.persistent_id)
        result.class.should == Bindery::Spreadsheet
        result.id.should == @version2.id
      end
    end
    describe "version_with_current_file_binding" do
      it "should return the node where the latest file binding was set" do
        ss = Bindery::Spreadsheet.find_by_identifier(@version4.id)
        result = ss.version_with_current_file_binding
        result.class.should == Bindery::Spreadsheet
        result.id.should == @version2.id
      end
    end
  end

end
