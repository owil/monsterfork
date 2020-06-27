# frozen_string_literal: true

class PostStatusService < BaseService
  include Redisable
  include ImgProxyHelper

  MIN_SCHEDULE_OFFSET = 5.minutes.freeze

  # Post a text status update, fetch and notify remote users mentioned
  # @param [Account] account Account from which to post
  # @param [Hash] options
  # @option [String] :text Message
  # @option [Status] :thread Optional status to reply to
  # @option [Boolean] :sensitive
  # @option [String] :visibility
  # @option [String] :spoiler_text
  # @option [String] :title
  # @option [String] :footer
  # @option [String] :language
  # @option [String] :scheduled_at
  # @option [Hash] :poll Optional poll to attach
  # @option [Enumerable] :media_ids Optional array of media IDs to attach
  # @option [Doorkeeper::Application] :application
  # @option [String] :idempotency Optional idempotency key
  # @option [Boolean] :with_rate_limit
  # @option [Status] :status Edit an existing status
  # @option [Enumerable] :mentions Optional array of Mentions to include
  # @option [Enumerable] :tags Option array of tag names to include
  # @option [Boolean] :publish If true, status will be published
  # @option [Boolean] :notify If false, status will not be delivered to local timelines or mentions
  # @option [String] :expires_at If set, automatically delete at this time (UTC)
  # @option [String] :publish_at If set, automatically publish at this time (UTC)
  # @return [Status]
  def call(account, options = {})
    @account     = account
    @options     = options
    @text        = @options[:text] || ''
    @in_reply_to = @options[:thread]
    @expires_at  = @options[:expires_at]&.to_datetime
    @publish_at  = @options[:publish_at]&.to_datetime

    @expires_at ||= Time.now.utc + @account.user&.setting_unpublish_in.to_i.minutes if @account.user&.setting_unpublish_in.to_i.positive?
    @publish_at ||= Time.now.utc + @account.user&.setting_publish_in.to_i.minutes if @account.user&.setting_publish_in.to_i.positive?

    @options[:publish] ||= !(account.user&.setting_manual_publish || @publish_at.present?)

    raise Mastodon::NotPermittedError if different_author?

    @tag_names   = (@options[:tags] || []).select { |tag| tag =~ /\A(#{Tag::HASHTAG_NAME_RE})\z/i }
    @mentions    = @options[:mentions] || []

    return idempotency_duplicate if idempotency_given? && idempotency_duplicate?

    validate_media!
    preprocess_attributes!

    if scheduled?
      schedule_status!
    elsif @options[:status].present? && status_exists?
      update_status!
    else
      process_status!
      postprocess_status!
      bump_potential_friendship! if @options[:publish]
    end

    redis.setex(idempotency_key, 3_600, @status.id) if idempotency_given?

    @status
  end

  private

  def preprocess_attributes!
    if @text.blank? && @options[:spoiler_text].present?
      @text = '.'
      if @media&.find(&:video?) || @media&.find(&:gifv?)
        @text = '📹'
      elsif @media&.find(&:audio?)
        @text = '🎵'
      elsif @media&.find(&:image?)
        @text = '🖼'
      end
    end
    @sensitive    = (@options[:sensitive].nil? ? @account.user&.setting_default_sensitive : @options[:sensitive]) || @options[:spoiler_text].present?
    @visibility   = @options[:visibility] || @account.user&.setting_default_privacy
    @visibility   = :unlisted if @visibility&.to_sym == :public && @account.silenced?
    @scheduled_at = @options[:scheduled_at]&.to_datetime
    @scheduled_at = nil if scheduled_in_the_past?
  rescue ArgumentError
    raise ActiveRecord::RecordInvalid
  end

  def process_status!
    # The following transaction block is needed to wrap the UPDATEs to
    # the media attachments when the status is created

    ApplicationRecord.transaction do
      @status = @account.statuses.create!(status_attributes)
    end

    @status.notify = @options[:notify] if @options[:notify].present?

    process_command_tags_service.call(@account, @status)
    process_hashtags_service.call(@status, nil, @tag_names)
    process_mentions_service.call(@status, mentions: @mentions, deliver: @options[:publish])
  end

  def schedule_status!
    status_for_validation = @account.statuses.build(status_attributes)

    if status_for_validation.valid?
      status_for_validation.destroy

      # The following transaction block is needed to wrap the UPDATEs to
      # the media attachments when the scheduled status is created

      ApplicationRecord.transaction do
        @status = @account.scheduled_statuses.create!(scheduled_status_attributes)
      end
    else
      raise ActiveRecord::RecordInvalid
    end
  end

  def postprocess_status!
    LinkCrawlWorker.perform_async(@status.id) unless @status.spoiler_text?
    DistributionWorker.perform_async(@status.id)

    return unless @options[:publish]

    ActivityPub::DistributionWorker.perform_async(@status.id) unless @status.local_only?
    PollExpirationNotifyWorker.perform_at(@status.poll.expires_at, @status.poll.id) if @status.poll
  end

  def update_status!
    tags = Tag.find_or_create_by_names(@tag_names)
    @status = UpdateStatusService.new.call(@options[:status], status_attributes, @mentions, tags)
  end

  def validate_media!
    return if @options[:media_ids].blank? || !@options[:media_ids].is_a?(Enumerable)

    raise Mastodon::ValidationError, I18n.t('media_attachments.validations.too_many') if @options[:media_ids].size > 4 || @options[:poll].present?

    @media = @options[:status].present? ? @account.media_attachments.where(status_id: [nil, @options[:status].id]) : @account.media_attachments.where(status_id: nil)
    @media = @media.where(id: @options[:media_ids].take(4).map(&:to_i))

    raise Mastodon::ValidationError, I18n.t('media_attachments.validations.images_and_video') if @media.size > 1 && @media.find(&:audio_or_video?)
    raise Mastodon::ValidationError, I18n.t('media_attachments.validations.not_ready') if @media.any?(&:not_processed?)
  end

  def language_from_option(str)
    ISO_639.find(str)&.alpha2
  end

  def process_mentions_service
    ProcessMentionsService.new
  end

  def process_hashtags_service
    ProcessHashtagsService.new
  end

  def process_command_tags_service
    ProcessCommandTagsService.new
  end

  def scheduled?
    @scheduled_at.present?
  end

  def idempotency_key
    "idempotency:status:#{@account.id}:#{@options[:idempotency]}"
  end

  def idempotency_given?
    @options[:idempotency].present?
  end

  def idempotency_duplicate
    if scheduled?
      @account.schedule_statuses.find(@idempotency_duplicate)
    else
      @account.statuses.find(@idempotency_duplicate)
    end
  end

  def idempotency_duplicate?
    @idempotency_duplicate = redis.get(idempotency_key)
  end

  def scheduled_in_the_past?
    @scheduled_at.present? && @scheduled_at <= Time.now.utc + MIN_SCHEDULE_OFFSET
  end

  def bump_potential_friendship!
    return if !@status.reply? || @account.id == @status.in_reply_to_account_id

    ActivityTracker.increment('activity:interactions')
    return if @account.following?(@status.in_reply_to_account_id)

    PotentialFriendshipTracker.record(@account.id, @status.in_reply_to_account_id, :reply)
  end

  def status_attributes
    {
      text: @text,
      original_text: @text,
      media_attachments: @media || [],
      thread: @in_reply_to,
      poll_attributes: poll_attributes,
      sensitive: @sensitive,
      spoiler_text: @options[:spoiler_text] || '',
      title: @options[:title],
      footer: @options[:footer],
      visibility: @visibility,
      language: language_from_option(@options[:language]) || @account.user&.setting_default_language&.presence || LanguageDetector.instance.detect(@text, @account),
      application: @options[:application],
      published: @options[:publish],
      content_type: @options[:content_type] || @account.user&.setting_default_content_type,
      rate_limit: @options[:with_rate_limit],
      expires_at: @expires_at,
      publish_at: @publish_at,
    }.compact
  end

  def scheduled_status_attributes
    {
      scheduled_at: @scheduled_at,
      media_attachments: @media || [],
      params: scheduled_options,
    }
  end

  def poll_attributes
    return if @options[:poll].blank?

    @options[:poll].merge(account: @account, voters_count: 0)
  end

  def scheduled_options
    @options.tap do |options_hash|
      options_hash[:in_reply_to_id]  = options_hash.delete(:thread)&.id
      options_hash[:application_id]  = options_hash.delete(:application)&.id
      options_hash[:scheduled_at]    = nil
      options_hash[:idempotency]     = nil
      options_hash[:with_rate_limit] = false
      options_hash[:mention_ids]     = options_hash.delete(:mentions)&.pluck(:id)
      options_hash[:status_id]       = options_hash.delete(:status)&.id
    end
  end

  def different_author?
    @options[:status].present? && @options[:status].account_id != @account.id
  end

  def status_exists?
    !(@options[:status].discarded? || @options[:status].destroyed?)
  end
end
