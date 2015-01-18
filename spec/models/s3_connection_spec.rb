require 'rails_helper'

describe S3Connection do
  describe "bucket" do
    it "should return the bucket with the given name" do
      subject.send(:conn).should_receive(:buckets).and_return({"myBucketName"=>"the bucket"})
      subject.bucket("myBucketName").should == "the bucket"
    end
  end
  
  describe "ensure_bucket_initialized" do
    it "should ensure that the pools bucket exists on s3 connection" do
      stub_bucket = double()
      stub_bucket.should_receive(:exists?).and_return(false)
      stub_bucket_collection = double()
      stub_bucket_collection.should_receive(:create).with("myBucketName", :acl => :private).and_return("the bucket")
      # NOTE: .buckets is called twice.  First time is returning a Hash, the other is returning an object that responds to .create
      # this is how the S3 API actually behaves, where .buckets returns an object that supports Hash accessor operator
      subject.send(:conn).should_receive(:buckets).and_return({"myBucketName"=>stub_bucket})
      subject.send(:conn).should_receive(:buckets).and_return(stub_bucket_collection)
      subject.ensure_bucket_initialized("myBucketName").should == "the bucket"
    end
  end
  
  describe "ensure_cors_for_uploads" do
    it "should ensure that the bucket cors will allow uploads from current host" do
      pending "Is S3 too complicated to stub here?"
      stub_bucket = stub()
      stub_bucket.should_receive(:exists?).and_return(true)
      stub_cors = {}
      stub_bucket.should_receive(:cors).and_return([stub_cors])
      # NOTE: .buckets is called twice.  First time is returning a Hash, the other is returning an object that responds to .create
      # this is how the S3 API actually behaves, where .buckets returns an object that supports Hash accessor operator
      subject.send(:conn).should_receive(:buckets).and_return({"myBucketName"=>stub_bucket})
      subject.ensure_bucket_initialized("myBucketName")
    end
  end
end
