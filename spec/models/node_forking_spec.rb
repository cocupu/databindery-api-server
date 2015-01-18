require 'rails_helper'

describe Node do
  describe ".fork" do
    let :subject do
      data = {'f1'=>'good', 'first_name' => 'Heathcliff', 'last_name' => 'Huxtable', 'title'=>'Dr.'}
      FactoryGirl.create(:node, data: data)
    end
    it "should create a child node that references the source node's data" do
      child = subject.fork
      expect(child).not_to eq(subject)
      expect(child.parent).to eq(subject)
      expect(child.model).to eq(subject.model)
      expect(child.pool).to eq(subject.pool)
      expect(child.is_fork?).to be_truthy
      expect(child.read_attribute(:data)).to be_empty
      expect(child.data).to eq(subject.data)
    end
    it "accepts attribute updates" do
      new_pool = FactoryGirl.create(:pool)
      new_model = FactoryGirl.create(:model)
      child = subject.fork(pool:new_pool, log:"Because I can.", model: new_model, modified_by_id:22)
      expect(child.pool).to eq(new_pool)
      expect(child.model).to eq(new_model)
      expect(child.modified_by_id).to eq(22)
      expect(child.log).to eq("Because I can.")
    end
  end
end