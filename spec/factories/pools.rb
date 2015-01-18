FactoryGirl.define do
  factory :pool do
    sequence :short_name do |n|
      "factory-pool_#{n}"
    end

    owner
    persistent_id "bindery-test-pool"

    # user_with_posts will create post data after the user has been created
    factory :pool_with_models do
      # posts_count is declared as an ignored attribute and available in
      # attributes on the factory, as well as the callback via the evaluator
      transient do
        posts_count 5
      end

      # the after(:create) yields two values; the user instance itself and the
      # evaluator, which stores all values from the factory, including ignored
      # attributes; `create_list`'s second argument is the number of records
      # to create and we make sure the user is associated properly to the post
      after(:create) do |pool, evaluator|
        FactoryGirl.create_list(:model, evaluator.posts_count, owner: pool.owner, pool: pool)
      end
    end

  end
end