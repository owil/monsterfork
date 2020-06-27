# frozen_string_literal: true
class PublishStatusService < BaseService
  include Redisable

  def call(status)
    return if status.published?

    @status = status

    update_status!
    reset_status_caches
    distribute
    bump_potential_friendship!
  end

  private

  def update_status!
    @status.update!(published: true, publish_at: nil, expires_at: @status.expires_at.blank? ? nil : Time.now.utc + (@status.expires_at - @status.created_at))
    ProcessMentionsService.new.call(@status)
  end

  def reset_status_caches
    Rails.cache.delete_matched("statuses/#{@status.id}-*")
    Rails.cache.delete("statuses/#{@status.id}")
    Rails.cache.delete(@status)
    Rails.cache.delete_matched("format:#{@status.id}:*")
    redis.zremrangebyscore("spam_check:#{@status.account.id}", @status.id, @status.id)
  end

  def distribute
    LinkCrawlWorker.perform_in(rand(1..30).seconds, @status.id) unless @status.spoiler_text?
    DistributionWorker.perform_async(@status.id)
    ActivityPub::DistributionWorker.perform_async(@status.id) if @status.local? && !@status.local_only?
  end

  def bump_potential_friendship!
    return if !@status.reply? || @status.account.id == @status.in_reply_to_account_id

    ActivityTracker.increment('activity:interactions')
    return if @status.account.following?(@status.in_reply_to_account_id)

    PotentialFriendshipTracker.record(@status.account.id, @status.in_reply_to_account_id, :reply)
  end
end
