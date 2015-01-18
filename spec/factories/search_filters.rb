# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :search_filter do
    field
    operator "MyString"
    values ["MyText"]
  end
end
