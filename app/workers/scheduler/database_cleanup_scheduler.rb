# frozen_string_literal: true

class Scheduler::DatabaseCleanupScheduler
  include Sidekiq::Worker

  sidekiq_options lock: :until_executed, retry: 0

  def perform
    Conversation.left_outer_joins(:statuses).where(statuses: { id: nil }).destroy_all
    Tag.left_outer_joins(:statuses).where(statuses: { id: nil }).destroy_all
    StatusStat.left_outer_joins(:status).where(statuses: { id: nil }).destroy_all
    Setting.rewhere(thing_type: 'User').where.not(thing_id: User.select(:id)).destroy_all
  end
end
