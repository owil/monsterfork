class BackfillAccountIdOnConversations < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    Rails.logger.info('Backfilling owners of conversation threads...')
    safety_assured do
      Conversation.left_outer_joins(:statuses).where(statuses: { id: nil }).in_batches.destroy_all
      execute('UPDATE conversations SET account_id = s.account_id FROM (SELECT account_id, conversation_id FROM statuses WHERE NOT reply) AS s WHERE conversations.id = s.conversation_id')
    end
  end

  def down
    true
  end
end
