# frozen_string_literal: true

require 'singleton'
class FeedManager
  include Singleton
  include Redisable

  # Maximum number of items stored in a single feed
  MAX_ITEMS = 1000

  # Number of items in the feed since last reblog of status
  # before the new reblog will be inserted. Must be <= MAX_ITEMS
  # or the tracking sets will grow forever
  REBLOG_FALLOFF = 50

  # Execute block for every active account
  # @yield [Account]
  # @return [void]
  def with_active_accounts(&block)
    Account.joins(:user).where('users.current_sign_in_at > ?', User::ACTIVE_DURATION.ago).find_each(&block)
  end

  # Redis key of a feed
  # @param [Symbol] type
  # @param [Integer] id
  # @param [Symbol] subtype
  # @return [String]
  def key(type, id, subtype = nil)
    return "feed:#{type}:#{id}" unless subtype

    "feed:#{type}:#{id}:#{subtype}"
  end

  # Check if the status should not be added to a feed
  # @param [Symbol] timeline_type
  # @param [Status] status
  # @param [Account|List] receiver
  # @return [Boolean]
  def filter?(timeline_type, status, receiver)
    case timeline_type
    when :home
      filter_from_home?(status, receiver.id, build_crutches(receiver.id, [status]), receiver.user&.filters_unknown?)
    when :list
      filter_from_list?(status, receiver) || filter_from_home?(status, receiver.account_id, build_crutches(receiver.account_id, [status]), receiver.account.user&.filters_unknown?)
    when :mentions
      filter_from_mentions?(status, receiver.id)
    when :direct
      filter_from_direct?(status, receiver.id)
    else
      false
    end
  end

  # Add a status to a home feed and send a streaming API update
  # @param [Account] account
  # @param [Status] status
  # @return [Boolean]
  def push_to_home(account, status)
    return false unless add_to_feed(:home, account.id, status, account.user&.home_reblogs?)

    trim(:home, account.id)
    PushUpdateWorker.perform_async(account.id, status.id, "timeline:#{account.id}") if push_update_required?("timeline:#{account.id}")
    true
  end

  # Remove a status from a home feed and send a streaming API update
  # @param [Account] account
  # @param [Status] status
  # @return [Boolean]
  def unpush_from_home(account, status, include_reblogs_list = true)
    return false unless remove_from_feed(:home, account.id, status, include_reblogs_list)

    redis.publish("timeline:#{account.id}", Oj.dump(event: :delete, payload: status.id.to_s))
    true
  end

  # Add a status to a list feed and send a streaming API update
  # @param [List] list
  # @param [Status] status
  # @return [Boolean]
  def push_to_list(list, status)
    return false if filter_from_list?(status, list)
    return false unless add_to_feed(:list, list.id, status, list.reblogs?)

    trim(:list, list.id)
    PushUpdateWorker.perform_async(list.account_id, status.id, "timeline:list:#{list.id}") if push_update_required?("timeline:list:#{list.id}")
    true
  end

  # Remove a status from a list feed and send a streaming API update
  # @param [List] list
  # @param [Status] status
  # @return [Boolean]
  def unpush_from_list(list, status)
    return false unless remove_from_feed(:list, list.id, status)

    redis.publish("timeline:list:#{list.id}", Oj.dump(event: :delete, payload: status.id.to_s))
    true
  end

  # Add a status to a linear direct message feed and send a streaming API update
  # @param [Account] account
  # @param [Status] status
  # @return [Boolean]
  def push_to_direct(account, status)
    return false unless add_to_feed(:direct, account.id, status)

    trim(:direct, account.id)
    PushUpdateWorker.perform_async(account.id, status.id, "timeline:direct:#{account.id}")
    true
  end

  # Remove a status from a linear direct message feed and send a streaming API update
  # @param [List] list
  # @param [Status] status
  # @return [Boolean]
  def unpush_from_direct(account, status)
    return false unless remove_from_feed(:direct, account.id, status)

    redis.publish("timeline:direct:#{account.id}", Oj.dump(event: :delete, payload: status.id.to_s))
    true
  end

  def unpush_status(account, status)
    return if account.blank? || status.blank?

    unpush_from_home(account, status)
    unpush_from_direct(account, status) if status.direct_visibility?

    account.lists_for_local_distribution.select(:id, :account_id).each do |list|
      unpush_from_list(list, status)
    end
  end

  def unpush_conversation(account, conversation)
    return if account.blank? || conversation.blank?

    conversation.statuses.reorder(nil).find_each do |status|
      unpush_status(account, status)
    end
  end

  # Fill a home feed with an account's statuses
  # @param [Account] from_account
  # @param [Account] into_account
  # @return [void]
  def merge_into_home(from_account, into_account)
    timeline_key = key(:home, into_account.id)
    reblogs      = into_account.user&.home_reblogs?
    no_unknown   = into_account.user&.filters_unknown?
    query        = from_account.statuses.where(visibility: [:public, :unlisted, :private]).includes(:preloadable_poll, reblog: :account).limit(FeedManager::MAX_ITEMS / 4)

    if redis.zcard(timeline_key) >= FeedManager::MAX_ITEMS / 4
      oldest_home_score = redis.zrange(timeline_key, 0, 0, with_scores: true).first.last.to_i
      query = query.where('id > ?', oldest_home_score)
    end

    statuses = query.to_a
    crutches = build_crutches(into_account.id, statuses)

    statuses.each do |status|
      next if filter_from_home?(status, into_account.id, crutches, no_unknown)

      add_to_feed(:home, into_account.id, status, reblogs)
    end

    trim(:home, into_account.id)
  end

  # Fill a list feed with an account's statuses
  # @param [Account] from_account
  # @param [List] list
  # @return [void]
  def merge_into_list(from_account, list)
    timeline_key = key(:list, list.id)
    reblogs      = list.account.user&.home_reblogs?
    no_unknown   = list.account.user&.filters_unknown?
    query        = from_account.statuses.where(visibility: [:public, :unlisted, :private]).includes(:preloadable_poll, reblog: :account).limit(FeedManager::MAX_ITEMS / 4)

    if redis.zcard(timeline_key) >= FeedManager::MAX_ITEMS / 4
      oldest_home_score = redis.zrange(timeline_key, 0, 0, with_scores: true).first.last.to_i
      query = query.where('id > ?', oldest_home_score)
    end

    statuses = query.to_a
    crutches = build_crutches(list.account_id, statuses)

    statuses.each do |status|
      next if filter_from_home?(status, list.account_id, crutches, no_unknown) || filter_from_list?(status, list)

      add_to_feed(:list, list.id, status, reblogs)
    end

    trim(:list, list.id)
  end

  # Remove an account's statuses from a home feed
  # @param [Account] from_account
  # @param [Account] into_account
  # @return [void]
  def unmerge_from_home(from_account, into_account)
    timeline_key      = key(:home, into_account.id)
    oldest_home_score = redis.zrange(timeline_key, 0, 0, with_scores: true)&.first&.last&.to_i || 0

    from_account.statuses.select('id, reblog_of_id').where('id > ?', oldest_home_score).reorder(nil).find_each do |status|
      remove_from_feed(:home, into_account.id, status)
    end
  end

  # Remove an account's statuses from a list feed
  # @param [Account] from_account
  # @param [List] list
  # @return [void]
  def unmerge_from_list(from_account, list)
    timeline_key      = key(:list, list.id)
    oldest_list_score = redis.zrange(timeline_key, 0, 0, with_scores: true)&.first&.last&.to_i || 0

    from_account.statuses.select('id, reblog_of_id').where('id > ?', oldest_list_score).reorder(nil).find_each do |status|
      remove_from_feed(:list, list.id, status, !list.reblogs?)
    end
  end

  # Clear all statuses from or mentioning target_account from a home feed
  # @param [Account] account
  # @param [Account] target_account
  # @return [void]
  def clear_from_home(account, target_account)
    timeline_key        = key(:home, account.id)
    timeline_status_ids = redis.zrange(timeline_key, 0, -1)
    statuses            = Status.where(id: timeline_status_ids).select(:id, :reblog_of_id, :account_id).to_a
    reblogged_ids       = Status.where(id: statuses.map(&:reblog_of_id).compact, account: target_account).pluck(:id)
    with_mentions_ids   = Mention.active.where(status_id: statuses.flat_map { |s| [s.id, s.reblog_of_id] }.compact, account: target_account).pluck(:status_id)

    target_statuses = statuses.select do |status|
      status.account_id == target_account.id || reblogged_ids.include?(status.reblog_of_id) || with_mentions_ids.include?(status.id) || with_mentions_ids.include?(status.reblog_of_id)
    end

    target_statuses.each do |status|
      unpush_from_home(account, status)
    end
  end

  # Clear all reblogs from a home feed
  # @param [Account] account
  # @return [void]
  def clear_reblogs_from_home(account)
    timeline_key        = key(:home, account.id)
    timeline_status_ids = redis.zrange(timeline_key, 0, -1)

    Status.reblogs.joins(:reblog).where(reblogs_statuses: { local: false }).where(id: timeline_status_ids).find_each do |status|
      unpush_from_home(account, status, false)
    end
  end

  # Populate list feeds of account from scratch
  # @param [Account] account
  # @return [void]
  def populate_lists(account)
    limit = FeedManager::MAX_ITEMS / 2

    account.owned_lists.includes(:accounts) do |list|
      timeline_key = key(:list, list.id)

      list.accounts.includes(:account_stat).find_each do |target_account|
        if redis.zcard(timeline_key) >= limit
          oldest_home_score = redis.zrange(timeline_key, 0, 0, with_scores: true).first.last.to_i
          last_status_score = Mastodon::Snowflake.id_at(account.last_status_at)

          # If the feed is full and this account has not posted more recently
          # than the last item on the feed, then we can skip the whole account
          # because none of its statuses would stay on the feed anyway
          next if last_status_score < oldest_home_score
        end

        statuses = target_account.statuses.published.without_reblogs.where(visibility: [:public, :unlisted, :private]).includes(:mentions, :preloadable_poll).limit(limit)
        crutches = build_crutches(account.id, statuses)

        statuses.each do |status|
          next if filter_from_list?(status, account.id) || filter_from_home?(status, account.id, crutches, account.user&.filters_unknown?)

          add_to_feed(:list, list.id, status, list.reblogs?)
        end

        trim(:list, list.id)
      end
    end
  end

  # Populate home feed of account from scratch
  # @param [Account] account
  # @return [void]
  def populate_home(account)
    limit        = FeedManager::MAX_ITEMS / 2
    reblogs      = account.user&.home_reblogs?
    no_unknown   = account.user&.filters_unknown?
    timeline_key = key(:home, account.id)

    account.statuses.limit(limit).each do |status|
      add_to_feed(:home, account.id, status, reblogs)
    end

    account.following.includes(:account_stat).find_each do |target_account|
      if redis.zcard(timeline_key) >= limit
        oldest_home_score = redis.zrange(timeline_key, 0, 0, with_scores: true).first.last.to_i
        last_status_score = Mastodon::Snowflake.id_at(account.last_status_at)

        # If the feed is full and this account has not posted more recently
        # than the last item on the feed, then we can skip the whole account
        # because none of its statuses would stay on the feed anyway
        next if last_status_score < oldest_home_score
      end

      statuses = target_account.statuses.published.where(visibility: [:public, :unlisted, :private]).includes(:mentions, :preloadable_poll, reblog: [:account, :mentions]).limit(limit)
      crutches = build_crutches(account.id, statuses)

      statuses.each do |status|
        next if filter_from_home?(status, account.id, crutches, no_unknown)

        add_to_feed(:home, account.id, status, reblogs, false)
      end

      trim(:home, account.id)
    end
  end

  # Populate direct feed of account from scratch
  # @param [Account] account
  # @return [void]
  def populate_direct_feed(account)
    added  = 0
    limit  = FeedManager::MAX_ITEMS / 2
    max_id = nil

    loop do
      statuses = Status.as_direct_timeline(account, limit, max_id)

      break if statuses.empty?

      statuses.each do |status|
        next if filter_from_direct?(status, account)

        added += 1 if add_to_feed(:direct, account.id, status)
      end

      break unless added.zero?

      max_id = statuses.last.id
    end
  end

  private

  # Trim a feed to maximum size by removing older items
  # @param [Symbol] type
  # @param [Integer] timeline_id
  # @return [void]
  def trim(type, timeline_id)
    timeline_key = key(type, timeline_id)
    reblog_key   = key(type, timeline_id, 'reblogs')

    # Remove any items past the MAX_ITEMS'th entry in our feed
    redis.zremrangebyrank(timeline_key, 0, -(FeedManager::MAX_ITEMS + 1))

    # Get the score of the REBLOG_FALLOFF'th item in our feed, and stop
    # tracking anything after it for deduplication purposes.
    falloff_rank  = FeedManager::REBLOG_FALLOFF
    falloff_range = redis.zrevrange(timeline_key, falloff_rank, falloff_rank, with_scores: true)
    falloff_score = falloff_range&.first&.last&.to_i

    return if falloff_score.nil?

    # Get any reblogs we might have to clean up after.
    redis.zrangebyscore(reblog_key, 0, falloff_score).each do |reblogged_id|
      # Remove it from the set of reblogs we're tracking *first* to avoid races.
      redis.zrem(reblog_key, reblogged_id)
      # Just drop any set we might have created to track additional reblogs.
      # This means that if this reblog is deleted, we won't automatically insert
      # another reblog, but also that any new reblog can be inserted into the
      # feed.
      redis.del(key(type, timeline_id, "reblogs:#{reblogged_id}"))
    end
  end

  # Check if there is a streaming API client connected
  # for the given feed
  # @param [String] timeline_key
  # @return [Boolean]
  def push_update_required?(timeline_key)
    redis.exists?("subscribed:#{timeline_key}")
  end

  # Check if the account is blocking or muting any of the given accounts
  # @param [Integer] receiver_id
  # @param [Array<Integer>] account_ids
  # @param [Symbol] context
  def blocks_or_mutes?(receiver_id, account_ids, context)
    Block.where(account_id: receiver_id, target_account_id: account_ids).any? ||
      (context == :home ? Mute.where(account_id: receiver_id, target_account_id: account_ids).any? : Mute.where(account_id: receiver_id, target_account_id: account_ids, hide_notifications: true).any?)
  end

  # Check if status should not be added to the home feed
  # @param [Status] status
  # @param [Integer] receiver_id
  # @param [Hash] crutches
  # @return [Boolean]
  def filter_from_home?(status, receiver_id, crutches, followed_only = false)
    return false if receiver_id == status.account_id
    return true  if !status.published? || crutches[:hiding_thread][status.conversation_id]
    return true  if status.reply? && (status.in_reply_to_id.nil? || status.in_reply_to_account_id.nil?)
    return true  if phrase_filtered?(status, receiver_id, :home)

    check_for_blocks = crutches[:active_mentions][status.id] || []
    check_for_blocks.concat([status.account_id])
    check_for_blocks.concat([status.in_reply_to_account_id]) if status.reply?

    if status.reblog?
      check_for_blocks.concat([status.reblog.account_id])
      check_for_blocks.concat(crutches[:active_mentions][status.reblog_of_id] || [])
      check_for_blocks.concat([status.reblog.in_reply_to_account_id]) if status.reblog.reply?
    end

    return true if check_for_blocks.any? { |target_account_id| crutches[:blocking][target_account_id] || crutches[:muting][target_account_id] }

    # Filter if...
    if status.reply? # ...it's a reply and...
      # ...you're not following the participants...
      should_filter   = (status.mentions.pluck(:account_id) - crutches[:following].keys).present?
      # ...and the author isn't replying to you...
      should_filter &&= receiver_id != status.in_reply_to_account_id

      return !!should_filter
    elsif status.reblog? # ...it's a boost and...
      # ...you don't follow the OP and they're non-local or they're silenced...
      should_filter = (followed_only || status.reblog.account.silenced?) && !crutches[:following][status.reblog.account_id]

      # ..or you're hiding boosts from them...
      should_filter ||= crutches[:hiding_reblogs][status.account_id]
      # ...or they're blocking you...
      should_filter ||= crutches[:blocked_by][status.reblog.account_id]
      # ...or you're blocking their domain...
      should_filter ||= crutches[:domain_blocking][status.reblog.account.domain]

      # ...or it's a reply...
      if !(should_filter || status.reblog.in_reply_to_account_id.nil?) && status.reblog.reply?
        # ...and you don't follow the participants...
        should_filter ||= (status.reblog.mentions.pluck(:account_ids) - crutches[:following].keys).present?
        # ...and the author isn't replying to you...
        should_filter &&= receiver_id != status.in_reply_to_account_id
      end

      return !!should_filter
    end

    !crutches[:following][status.account_id]
  end

  # Check if status should not be added to the mentions feed
  # @see NotifyService
  # @param [Status] status
  # @param [Integer] receiver_id
  # @return [Boolean]
  def filter_from_mentions?(status, receiver_id)
    return true if receiver_id == status.account_id
    return true if phrase_filtered?(status, receiver_id, :notifications)

    # This filter is called from NotifyService, but already after the sender of
    # the notification has been checked for mute/block. Therefore, it's not
    # necessary to check the author of the toot for mute/block again
    check_for_blocks = status.active_mentions.pluck(:account_id)
    check_for_blocks.concat([status.in_reply_to_account]) if status.reply? && !status.in_reply_to_account_id.nil?

    should_filter   = blocks_or_mutes?(receiver_id, check_for_blocks, :mentions)
    should_filter ||= (status.account.silenced? && !relationship_exists?(receiver_id, status.account_id))

    should_filter
  end

  def following?(account_id, target_account_id)
    Follow.where(account_id: account_id, target_account_id: target_account_id).exists?
  end

  def relationship_exists?(account_id, target_account_id)
    Follow.where(account_id: account_id, target_account_id: target_account_id)
          .or(Follow.where(account_id: target_account_id, target_account_id: account_id))
          .exists?
  end

  # Check if status should not be added to the linear direct message feed
  # @param [Status] status
  # @param [Integer] receiver_id
  # @return [Boolean]
  def filter_from_direct?(status, receiver_id)
    return false if receiver_id == status.account_id

    filter_from_mentions?(status, receiver_id)
  end

  # Check if status should not be added to the list feed
  # @param [Status] status
  # @param [List] list
  # @return [Boolean]
  def filter_from_list?(status, list)
    return true if (list.reblogs? && !status.reblog?) || (!list.reblogs? && status.reblog?)
    return true if status.reblog? ? status.reblog.account_id == list.account_id : status.account_id == list.account_id

    if status.reply? && status.in_reply_to_account_id != status.account_id
      should_filter = status.in_reply_to_account_id != list.account_id
      should_filter &&= !list.show_all_replies?
      should_filter &&= !(list.show_list_replies? && ListAccount.where(list_id: list.id, account_id: status.in_reply_to_account_id).exists?)

      return !!should_filter
    end

    false
  end

  # Check if the status hits a phrase filter
  # @param [Status] status
  # @param [Integer] receiver_id
  # @param [Symbol] context
  # @return [Boolean]
  def phrase_filtered?(status, receiver_id, context)
    active_filters = Rails.cache.fetch("filters:#{receiver_id}") { CustomFilter.where(account_id: receiver_id).active_irreversible.to_a }.to_a

    active_filters.select! { |filter| filter.context.include?(context.to_s) && !filter.expired? }

    active_filters.map! do |filter|
      if filter.whole_word
        sb = filter.phrase =~ /\A[[:word:]]/ ? '\b' : ''
        eb = filter.phrase =~ /[[:word:]]\z/ ? '\b' : ''

        /(?mix:#{sb}#{Regexp.escape(filter.phrase)}#{eb})/
      else
        /#{Regexp.escape(filter.phrase)}/i
      end
    end

    return false if active_filters.empty?

    combined_regex = active_filters.reduce { |memo, obj| Regexp.union(memo, obj) }
    status         = status.reblog if status.reblog?

    combined_text = [
      Formatter.instance.plaintext(status),
      status.spoiler_text,
      status.preloadable_poll ? status.preloadable_poll.options.join("\n\n") : nil,
      status.media_attachments.map(&:description).join("\n\n"),
    ].compact.join("\n\n")

    !combined_regex.match(combined_text).nil?
  end

  # Adds a status to an account's feed, returning true if a status was
  # added, and false if it was not added to the feed. Note that this is
  # an internal helper: callers must call trim or push updates if
  # either action is appropriate.
  # @param [Symbol] timeline_type
  # @param [Integer] account_id
  # @param [Status] status
  # @param [Boolean] home_reblogs
  # @param [Boolean] stream
  # @return [Boolean]
  def add_to_feed(timeline_type, account_id, status, home_reblogs = true, stream = true)
    timeline_key = key(timeline_type, account_id)
    reblog_key   = key(timeline_type, account_id, 'reblogs')

    if status.reblog?
      add_to_reblogs(account_id, status, stream) if timeline_type == :home
      return false unless home_reblogs || (timeline_type == :home && (status.reblog.local? || following?(account_id, status.reblog.account_id)))
    end

    if status.reblog?
      # If the original status or a reblog of it is within
      # REBLOG_FALLOFF statuses from the top, do not re-insert it into
      # the feed
      rank = redis.zrevrank(timeline_key, status.reblog_of_id)

      return false if !rank.nil? && rank < FeedManager::REBLOG_FALLOFF

      # The ordered set at `reblog_key` holds statuses which have a reblog
      # in the top `REBLOG_FALLOFF` statuses of the timeline
      if redis.zadd(reblog_key, status.id, status.reblog_of_id, nx: true)
        # This is not something we've already seen reblogged, so we
        # can just add it to the feed (and note that we're reblogging it).
        redis.zadd(timeline_key, status.id, status.id)
      else
        # Another reblog of the same status was already in the
        # REBLOG_FALLOFF most recent statuses, so we note that this
        # is an "extra" reblog, by storing it in reblog_set_key.
        reblog_set_key = key(timeline_type, account_id, "reblogs:#{status.reblog_of_id}")
        redis.sadd(reblog_set_key, status.id)
        return false
      end
    else
      # A reblog may reach earlier than the original status because of the
      # delay of the worker deliverying the original status, the late addition
      # by merging timelines, and other reasons.
      # If such a reblog already exists, just do not re-insert it into the feed.
      return false unless redis.zscore(reblog_key, status.id).nil?

      redis.zadd(timeline_key, status.id, status.id)
    end

    add_to_reblogs(account_id, status, stream) if timeline_type == :home && status.reblog?

    true
  end

  # Removes an individual status from a feed, correctly handling cases
  # with reblogs, and returning true if a status was removed. As with
  # `add_to_feed`, this does not trigger push updates, so callers must
  # do so if appropriate.
  # @param [Symbol] timeline_type
  # @param [Integer] account_id
  # @param [Status] status
  # @param [Boolean] include_reblogs_list
  # @return [Boolean]
  def remove_from_feed(timeline_type, account_id, status, include_reblogs_list = true)
    timeline_key = key(timeline_type, account_id)
    reblog_key   = key(timeline_type, account_id, 'reblogs')

    remove_from_reblogs(account_id, status) if include_reblogs_list && timeline_type == :home && status.reblog?

    if status.reblog?
      # 1. If the reblogging status is not in the feed, stop.
      status_rank = redis.zrevrank(timeline_key, status.id)
      return false if status_rank.nil?

      # 2. Remove reblog from set of this status's reblogs.
      reblog_set_key = key(timeline_type, account_id, "reblogs:#{status.reblog_of_id}")

      redis.srem(reblog_set_key, status.id)
      redis.zrem(reblog_key, status.reblog_of_id)
      # 3. Re-insert another reblog or original into the feed if one
      # remains in the set. We could pick a random element, but this
      # set should generally be small, and it seems ideal to show the
      # oldest potential such reblog.
      other_reblog = redis.smembers(reblog_set_key).map(&:to_i).min

      redis.zadd(timeline_key, other_reblog, other_reblog) if other_reblog
      redis.zadd(reblog_key, other_reblog, status.reblog_of_id) if other_reblog

      # 4. Remove the reblogging status from the feed (as normal)
      # (outside conditional)
    else
      # If the original is getting deleted, no use for reblog references
      redis.del(key(timeline_type, account_id, "reblogs:#{status.id}"))
      redis.zrem(reblog_key, status.id)
    end

    redis.zrem(timeline_key, status.id)
  end

  # Pre-fetch various objects and relationships for given statuses that
  # are going to be checked by the filtering methods
  # @param [Integer] receiver_id
  # @param [Array<Status>] statuses
  # @return [Hash]
  def build_crutches(receiver_id, statuses)
    crutches = {}

    mentions = Mention.active.where(status_id: statuses.flat_map { |s| [s.id, s.reblog_of_id] }.compact).pluck(:status_id, :account_id)
    participants = statuses.flat_map { |s| [s.account_id, s.in_reply_to_account_id, s.reblog&.account_id, s.reblog&.in_reply_to_account_id].compact } | mentions.map { |m| m[1] }

    crutches[:active_mentions] = mentions.each_with_object({}) { |(id, account_id), mapping| (mapping[id] ||= []).push(account_id) }

    crutches[:following]       = Follow.where(account_id: receiver_id, target_account_id: participants).pluck(:target_account_id).each_with_object({}) { |id, mapping| mapping[id] = true }
    crutches[:hiding_reblogs]  = Follow.where(account_id: receiver_id, target_account_id: statuses.map { |s| s.account_id if s.reblog? }.compact, show_reblogs: false).pluck(:target_account_id).each_with_object({}) { |id, mapping| mapping[id] = true }
    crutches[:blocking]        = Block.where(account_id: receiver_id, target_account_id: participants).pluck(:target_account_id).each_with_object({}) { |id, mapping| mapping[id] = true }
    crutches[:muting]          = Mute.where(account_id: receiver_id, target_account_id: participants).pluck(:target_account_id).each_with_object({}) { |id, mapping| mapping[id] = true }
    crutches[:domain_blocking] = AccountDomainBlock.where(account_id: receiver_id, domain: statuses.map { |s| s.reblog&.account&.domain }.compact).pluck(:domain).each_with_object({}) { |domain, mapping| mapping[domain] = true }
    crutches[:blocked_by]      = Block.where(target_account_id: receiver_id, account_id: statuses.map { |s| s.reblog&.account_id }.compact).pluck(:account_id).each_with_object({}) { |id, mapping| mapping[id] = true }
    crutches[:hiding_thread]   = ConversationMute.where(account_id: receiver_id, conversation_id: statuses.map(&:conversation_id).compact).pluck(:conversation_id).each_with_object({}) { |id, mapping| mapping[id] = true }

    crutches
  end

  def find_or_create_reblogs_list(account_id)
    List.find_or_create_by!(account_id: account_id, reblogs: true) do |list|
      list.title = I18n.t('accounts.reblogs')
      list.replies_policy = :no_replies
    end
  end

  def add_to_reblogs(account_id, status, stream = true)
    reblogs_list_id = find_or_create_reblogs_list(account_id).id
    return unless add_to_feed(:list, reblogs_list_id, status)

    trim(:list, reblogs_list_id)
    return unless stream && push_update_required?("timeline:list:#{reblogs_list_id}")

    PushUpdateWorker.perform_async(account_id, status.id, "timeline:list:#{reblogs_list_id}")
  end

  def remove_from_reblogs(account_id, status)
    reblogs_list_id = find_or_create_reblogs_list(account_id).id
    return unless remove_from_feed(:list, reblogs_list_id, status)

    redis.publish("timeline:list:#{reblogs_list_id}", Oj.dump(event: :delete, payload: status.id.to_s))
  end
end
