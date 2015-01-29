FactoryGirl.define do
  factory :login, class: LoginCredential, aliases: [:login_credential] do
    sequence :email do |n|
      "person#{n}@cocupu.com"
    end
    provider 'email'
    password 'notblank'
  end
end