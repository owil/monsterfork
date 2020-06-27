# frozen_string_literal: true

class MuteStatusService < BaseService
  def call(account, status)
    return if account.blank? || status.blank?

    account.mute_status!(status)
    FeedManager.instance.unpush_status(account, status)
  end
end
