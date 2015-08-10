require 'sidekiq/api'


namespace :sidekiq do
  namespace :queue do
    desc 'Clear out all of the sidekiq queues'
    task :clear do
      Sidekiq::Queue.new.clear
      Sidekiq::RetrySet.new.clear
      Sidekiq::ScheduledSet.new.clear
    end
  end
end

