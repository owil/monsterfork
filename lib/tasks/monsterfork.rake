# frozen_string_literal: true
namespace :monsterfork do
  desc 'Compute post nesting levels (this may take a very long time!)'
  task compute_nesting_levels: :environment do
    Rails.logger.info('Setting post nesting level for orphaned replies...')
    Status.select(:id, :account_id).where(reply: true, in_reply_to_id: nil).reorder(nil).in_batches.update_all(nest_level: 1)

    count = 1.0
    total = Conversation.count

    Conversation.reorder('conversations.id DESC').find_each do |conversation|
      Rails.logger.info("(#{(count / total * 100).to_i}%) Computing post nesting levels for all threads...")

      conversation.statuses.where(reply: true).reorder('statuses.id ASC').find_each do |status|
        level = [status.thread&.account_id == status.account_id ? status.thread&.nest_level.to_i : status.thread&.nest_level.to_i + 1, 127].min
        status.update(nest_level: level) if level != status.nest_level
      end

      count += 1
    end
  end

  desc '(Re-)announce instance actor to allow-listed servers'
  task announce_instance_actor: :environment  do
    Rails.logger.info('Announcing instance actor to all allowed servers...')
    ActivityPub::UpdateDistributionWorker.new.perform(Account.representative.id)
    Rails.logger.info('Done!')
  end
end
