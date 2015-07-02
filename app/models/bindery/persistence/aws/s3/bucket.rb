# Class for representing S3 Buckets as StorageContainers
# Notes: Pools always have a default S3 bucket in the DataBindery S3 account.
# Currently those are not tracked as Bucket (StorageContainer) objects internally
# because the pool itself serves as a representation of the container & its contents.
# Eventually, we might allow you to set any Bucket as the default bucket for a pool.
# (then uploads will be stored in that Bucket instead of in DataBindery's S3 account)
class Bindery::Persistence::AWS::S3::Bucket < Bindery::Persistence::StorageContainer
  self.table_name = "s3_buckets"
  belongs_to :aws_credentials
end