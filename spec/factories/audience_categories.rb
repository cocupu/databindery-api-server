# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :audience_category do
    pool_id 1
    name "MyString"
    description "MyText"
  end
end
