FactoryGirl.define do
  factory :spreadsheet, :class=>Bindery::Spreadsheet do
    pool
    model
  end

  factory :worksheet do
    spreadsheet
    order 0
    after(:create) do |worksheet, evaluator|
      FactoryGirl.create_list(:spreadsheet_row, 5, worksheet: worksheet)
    end
  end

  factory :spreadsheet_row do
    values {  5.times.map { generate(:random_data)} }
  end
end