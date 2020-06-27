# frozen_string_literal: true

class Scheduler::StatusCleanupScheduler
  include Sidekiq::Worker

  sidekiq_options lock: :until_executed, retry: 0

  def perform
    Status.with_discarded.expired.find_each do |status|
      RemoveStatusService.new.call(status, unpublish: !(status.discarded? || status.account&.user&.setting_unpublish_delete))
    end
  end
end
