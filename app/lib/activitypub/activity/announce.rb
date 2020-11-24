# frozen_string_literal: true

class ActivityPub::Activity::Announce < ActivityPub::Activity
  def perform
    return reject_payload! if delete_arrived_first?(@json['id'])

    RedisLock.acquire(lock_options) do |lock|
      if lock.acquired?
        original_status = status_from_object

        return reject_payload! if original_status.nil? || !announceable?(original_status)

        @status = Status.find_by(account: @account, reblog: original_status)

        return @status unless @status.nil?

        @status = Status.create!(
          account: @account,
          reblog: original_status,
          uri: @json['id'],
          created_at: @json['published'],
          override_timestamps: @options[:override_timestamps],
          visibility: visibility_from_audience
        )

        distribute(@status)
      else
        raise Mastodon::RaceConditionError
      end
    end

    @status
  end

  private

  def audience_to
    as_array(@json['to']).map { |x| value_or_id(x) }
  end

  def audience_cc
    as_array(@json['cc']).map { |x| value_or_id(x) }
  end

  def visibility_from_audience
    if audience_to.include?(ActivityPub::TagManager::COLLECTIONS[:public])
      @account.private? ? :private : :public
    elsif audience_cc.include?(ActivityPub::TagManager::COLLECTIONS[:public])
      @account.private? ? :private : :unlisted
    elsif audience_to.include?(@account.followers_url)
      :private
    else
      :limited
    end
  end

  def announceable?(status)
    status.account_id == @account.id || status.distributable?
  end

  def lock_options
    { redis: Redis.current, key: "announce:#{@object['id']}" }
  end
end
