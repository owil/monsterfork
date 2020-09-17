# frozen_string_literal: true

class FanOutOnWriteService < BaseService
  # Push a status into home and mentions feeds
  # @param [Status] status
  def call(status, only_to_self: false)
    raise Mastodon::RaceConditionError if status.visibility.nil?

    deliver_to_self(status) if status.account.local?
    return if only_to_self || !status.published?

    if status.direct_visibility?
      deliver_to_mentioned_followers(status)
      deliver_to_direct_timelines(status)
      deliver_to_own_conversation(status)
    elsif status.limited_visibility?
      deliver_to_mentioned_followers(status)
      deliver_to_lists(status)
    else
      deliver_to_followers(status)
      deliver_to_lists(status)
    end

    return if status.account.silenced?

    render_anonymous_payload(status.proper)
    deliver_to_hashtags(status)

    if status.reblog?
      if status.local? && status.reblog.public_visibility? && !status.reblog.account.silenced?
        deliver_to_public(status.reblog)
        deliver_to_media(status.reblog) if status.reblog.media_attachments.any?
      end
      return
    end

    deliver_to_hashtags(status) if status.distributable?
    return if !status.public_visibility? || (status.reply? && status.in_reply_to_account_id != status.account_id)

    deliver_to_media(status, true) if status.media_attachments.any?
    deliver_to_public(status, true)
  end

  private

  def deliver_to_self(status)
    Rails.logger.debug "Delivering status #{status.id} to author"
    FeedManager.instance.push_to_home(status.account, status)
    FeedManager.instance.push_to_direct(status.account, status) if status.direct_visibility?
  end

  def deliver_to_followers(status)
    Rails.logger.debug "Delivering status #{status.id} to followers"

    status.account.followers_for_local_distribution.select(:id).reorder(nil).find_in_batches do |followers|
      FeedInsertWorker.push_bulk(followers) do |follower|
        [status.id, follower.id, :home]
      end
    end
  end

  def deliver_to_lists(status)
    Rails.logger.debug "Delivering status #{status.id} to lists"

    status.account.lists_for_local_distribution.select(:id).reorder(nil).find_in_batches do |lists|
      FeedInsertWorker.push_bulk(lists) do |list|
        [status.id, list.id, :list]
      end
    end
  end

  def deliver_to_mentioned_followers(status)
    Rails.logger.debug "Delivering status #{status.id} to limited followers"

    status.mentions.joins(:account).merge(status.account.followers_for_local_distribution).select(:id, :account_id).reorder(nil).find_in_batches do |mentions|
      FeedInsertWorker.push_bulk(mentions) do |mention|
        [status.id, mention.account_id, :home]
      end
    end
  end

  def render_anonymous_payload(status)
    @payload = InlineRenderer.render(status, nil, :status)
    @payload = Oj.dump(event: :update, payload: @payload)
  end

  def deliver_to_hashtags(status)
    Rails.logger.debug "Delivering status #{status.id} to hashtags"

    status.tags.pluck(:name).each do |hashtag|
      Redis.current.publish("timeline:hashtag:#{hashtag.mb_chars.downcase}", @payload)
      Redis.current.publish("timeline:hashtag:#{hashtag.mb_chars.downcase}:local", @payload) if status.local?
    end
  end

  def deliver_to_public(status, tavern = false)
    key = "timeline:public:#{status.id}"
    return if Redis.current.get(key)

    Rails.logger.debug "Delivering status #{status.id} to public timeline"

    Redis.current.set(key, 1, ex: 2.hours)

    Redis.current.publish('timeline:public', @payload) if status.local? || !tavern
    Redis.current.publish('timeline:public:local', @payload) if status.local?
    Redis.current.publish('timeline:public:remote', @payload)
  end

  def deliver_to_media(status, tavern = false)
    key = "timeline:public:#{status.id}"
    return if Redis.current.get(key)

    Rails.logger.debug "Delivering status #{status.id} to media timeline"

    Redis.current.publish('timeline:public:media', @payload) if status.local? || !tavern
    Redis.current.publish('timeline:public:local:media', @payload) if status.local?
    Redis.current.publish('timeline:public:remote:media', @payload)
  end

  def deliver_to_direct_timelines(status)
    Rails.logger.debug "Delivering status #{status.id} to direct timelines"

    FeedInsertWorker.push_bulk(status.mentions.includes(:account).map(&:account).select(&:local?)) do |account|
      [status.id, account.id, :direct]
    end
  end

  def deliver_to_own_conversation(status)
    AccountConversation.add_status(status.account, status)
  end
end
