module Bindery
  class S3BucketImporter

    def s3
      @s3 ||= AWS::S3.new(:access_key_id => AWS.config.access_key_id,
                     :secret_access_key => AWS.config.secret_access_key)
    end

    # @example Import the Seed data (Pullahari RDI Shrine Hall Images) from the Bucket with id "5f496210-5ee3-0132-962e-12313819959a"
    #   import_bucket("5f496210-5ee3-0132-962e-12313819959a")
    def import_bucket(bucket_id, pool)
      bucket = s3.buckets[bucket_id]
      bucket.objects.each do |obj|
        unless obj.key.last == "/"
          puts obj.key
          FileEntity.register(pool, :data=>{"bucket"=>bucket_id,"file_name"=>File.basename(obj.key), "mime_type"=>obj.content_type, "file_size"=>obj.content_length, "storage_location_id"=>obj.key})
        end
      end
    end

  end
end