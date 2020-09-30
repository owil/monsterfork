# frozen_string_literal: true

class ProcessMentionsService < BaseService
  include Payloadable

  # Scan status for mentions and fetch remote mentioned users, create
  # local mention pointers, send Salmon notifications to mentioned
  # remote users
  # @param [Status] status
  # @option [Enumerable] :mentions Mentions to include
  # @option [Boolean] :deliver Deliver mention notifications
  def call(status, mentions: [], deliver: true)
    return unless status.local? && !(status.frozen? || status.destroyed?)

    @status = status
    @status.text, mentions = ResolveMentionsService.new.call(@status, mentions: mentions)
    @status.save!

    return unless deliver

    check_for_spam(status)

    @activitypub_json = {}
    mentions.each { |mention| create_notification(mention) }
  end

  private

  def create_notification(mention)
    mentioned_account = mention.account

    if mentioned_account.local?
      LocalNotificationWorker.perform_async(mentioned_account.id, mention.id, mention.class.name, :mention) unless !@status.notify? || mention.silent?
    elsif mentioned_account.activitypub? && !@status.local_only?
      ActivityPub::DeliveryWorker.perform_async(activitypub_json(mentioned_account.domain), mention.status.account_id, mentioned_account.inbox_url)
    end
  end

  def activitypub_json(domain)
    @activitypub_json[domain] ||= Oj.dump(serialize_payload(ActivityPub::ActivityPresenter.from_status(@status, embed: false), ActivityPub::ActivitySerializer, signer: @status.account, target_domain: domain))
  end

  def check_for_spam(status)
    SpamCheck.perform(status)
  end
end
