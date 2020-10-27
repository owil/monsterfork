# frozen_string_literal: true

class MuteService < BaseService
  def call(account, target_account, notifications: nil, timelines_only: nil, duration: 0)
    return if account.id == target_account.id

    mute = account.mute!(target_account, notifications: notifications, timelines_only: timelines_only, duration: duration)

    if mute.hide_notifications?
      BlockWorker.perform_async(account.id, target_account.id, defederate: false)
    else
      MuteWorker.perform_async(account.id, target_account.id)
    end

    DeleteMuteWorker.perform_at(duration.seconds, mute.id) if duration != 0

    mute
  end
end
