# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :field do
    name "MyString"
    type "TextField"
    uri "MyString"
    code "MyString"
    label "MyString"
  end
  factory :model_name_field, class:Field do
    name "model_name"
  end
  factory :model_field, class:IntegerField do
    name "model"
  end
  factory :subject_field, class:TextField do
    name "subject"
  end
  factory :title_field, class:TextField do
    name "title"
    multivalue true
  end
  factory :full_name_field, class:TextField do
    name 'Name'
    uri "dc:description"
    code "full_name"
  end
  factory :first_name_field, class:TextField do
    name "first_name"
  end
  factory :last_name_field, class:TextField do
    name "last_name"
  end
  factory :location_field, class:Field do
    name "location"
  end
  factory :access_level_field, class:Field do
    name "access_level"
  end
  factory :text_area_field, class:TextArea do
    name "notes"
  end
  factory :date_field, class:DateField do
    name "important_date"
  end
  factory :integer_field, class:IntegerField do
    name "a_number"
  end
  factory :association, class:OrderedListAssociation do
    name "an_association"
    label "association_label"
  end
end
