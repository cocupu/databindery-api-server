FactoryGirl.define do

  factory :generic_pool, class: Pool do
    sequence :short_name do |n|
      "factory-dat-pool_#{n}"
    end
    owner
    persistent_id "bindery-test-pool"
  end

  factory :sql_backed_pool, aliases: [:pool] do
    sequence :short_name do |n|
      "factory-sql-pool_#{n}"
    end

    owner
    persistent_id "bindery-test-sql-pool"

    # user_with_posts will create post data after the user has been created
    factory :sql_backed_pool_with_models do
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

  factory :dat_backed_pool, aliases: [] do
    sequence :short_name do |n|
      "factory-dat-pool_#{n}"
    end

    owner
    persistent_id "bindery-test-dat-pool"

    # user_with_posts will create post data after the user has been created
    factory :dat_backed_pool_with_models, aliases: [:pool_with_models] do
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