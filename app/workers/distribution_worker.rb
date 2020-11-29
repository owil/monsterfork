# frozen_string_literal: true

class DistributionWorker
  include Sidekiq::Worker

  def perform(status_id, only_to_self = false, only_to_tavern = false)
    RedisLock.acquire(redis: Redis.current, key: "distribute:#{status_id}") do |lock|
      if lock.acquired?
        status = Status.find(status_id)
        only_to_self ||= !(status.published? || status.notify?)
        FanOutOnWriteService.new.call(status, only_to_self: only_to_self, only_to_tavern: only_to_tavern)
      else
        raise Mastodon::RaceConditionError
      end
    end
  rescue ActiveRecord::RecordNotFound
    true
  end
end
