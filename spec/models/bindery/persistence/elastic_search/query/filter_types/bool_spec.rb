require 'rails_helper'
describe Bindery::Persistence::ElasticSearch::Query::FilterTypes::Bool do

  describe ".must" do
    it "tracks the bool['must'] filter and is idempotent" do
      returned = subject.must
      created_filter = subject.filters.select{|f| f.type == "must"}.first
      expect(returned).to eq(created_filter)
      expect(subject.must).to eq(created_filter)
      expect(subject.filters.select{|f| f.type == "must"}.count).to eq 1
    end
  end

  describe ".must_not" do
    it "tracks the bool['must_not'] filter and is idempotent" do
      returned = subject.must_not
      created_filter = subject.filters.select{|f| f.type == "must_not"}.first
      expect(returned).to eq(created_filter)
      expect(subject.must_not).to eq(created_filter)
      expect(subject.filters.select{|f| f.type == "must_not"}.count).to eq 1
    end
  end

  describe ".should" do
    it "tracks the bool['should'] filter and is idempotent" do
      returned = subject.should
      created_filter = subject.filters.select{|f| f.type == "should"}.first
      expect(returned).to eq(created_filter)
      expect(subject.should).to eq(created_filter)
      expect(subject.filters.select{|f| f.type == "should"}.count).to eq 1
    end
  end

  describe "add_must_match" do
    it "adds match filters to the bool['must'] array" do
      subject.add_must_match({"afield" => "avalue"})
      expect(subject.as_json).to eq({bool:{must:[{match:{'afield'=>'avalue'}}]}}.as_json)
      subject.add_must_match({"anotherfield" => "anothervalue"})
      expect(subject.as_json).to eq({bool:{must:[{match:{'afield'=>'avalue'}},{match:{'anotherfield'=>'anothervalue'}}]}}.as_json)
    end
    it "wraps the match filter in a query filter if the context is not :query" do
      subject.add_must_match({"afield" => "avalue"}, context: :filter)
      expect(subject.as_json).to eq({bool:{must:[{query:{match:{'afield'=>'avalue'}}}]}}.as_json)
      subject.add_must_match({"anotherfield" => "anothervalue"}, context: :filter)
      expect(subject.as_json).to eq({bool:{must:[{query:{match:{'afield'=>'avalue'}}},{query:{match:{'anotherfield'=>'anothervalue'}}}]}}.as_json)
    end
  end

  describe "add_must_not_match" do
    it "adds match filters to the bool['must_not'] array" do
      subject.add_must_not_match({"afield" => "avalue"})
      expect(subject.as_json).to eq({bool:{must_not:[{match:{'afield'=>'avalue'}}]}}.as_json)
      subject.add_must_not_match({"anotherfield" => "anothervalue"})
      expect(subject.as_json).to eq({bool:{must_not:[{match:{'afield'=>'avalue'}},{match:{'anotherfield'=>'anothervalue'}}]}}.as_json)
    end
    it "wraps the match filter in a query filter if the context is not :query" do
      subject.add_must_not_match({"afield" => "avalue"}, context: :filter)
      expect(subject.as_json).to eq({bool:{must_not:[{query:{match:{'afield'=>'avalue'}}}]}}.as_json)
      subject.add_must_not_match({"anotherfield" => "anothervalue"}, context: :filter)
      expect(subject.as_json).to eq({bool:{must_not:[{query:{match:{'afield'=>'avalue'}}},{query:{match:{'anotherfield'=>'anothervalue'}}}]}}.as_json)
    end
  end

  describe "add_should_match" do
    it "adds match filters to the bool['should'] array" do
      subject.add_should_match({"afield" => "avalue"})
      expect(subject.as_json).to eq({bool:{should:[{match:{'afield'=>'avalue'}}]}}.as_json)
      subject.add_should_match({"anotherfield" => "anothervalue"})
      expect(subject.as_json).to eq({bool:{should:[{match:{'afield'=>'avalue'}},{match:{'anotherfield'=>'anothervalue'}}]}}.as_json)
    end
    it "wraps the match filter in a query filter if the context is not :query" do
      subject.add_should_match({"afield" => "avalue"}, context: :filter)
      expect(subject.as_json).to eq({bool:{should:[{query:{match:{'afield'=>'avalue'}}}]}}.as_json)
      subject.add_should_match({"anotherfield" => "anothervalue"}, context: :filter)
      expect(subject.as_json).to eq({bool:{should:[{query:{match:{'afield'=>'avalue'}}},{query:{match:{'anotherfield'=>'anothervalue'}}}]}}.as_json)
    end
  end

end
