# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :s3_connection, class:Bindery::Persistence::AWS::S3::Connection do
    access_key_id '123456'
    secret_access_key '9909342'
  end
end
