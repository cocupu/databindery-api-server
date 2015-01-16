FactoryGirl.define do
  factory :identity, aliases: [:owner] do
    sequence :short_name do |n|
      "person#{n}"
    end
    after(:create) do |identity, evaluator|
      identity.login_credential ||= FactoryGirl.create :login_credential, email:"#{identity.short_name}@cocupu.com", identities:[identity]
    end
  end
end
