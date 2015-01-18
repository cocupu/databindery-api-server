FactoryGirl.define do
  factory :model do
    pool
    sequence :name do |n|
      "Factory model name #{n}"
    end
    fields_attributes [{"name"=>"Description", "type"=>"TextField", "uri"=>"dc:description", "code"=>"description"}]
    owner
  end
end