class BackfillConversationVisibility < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    Rails.logger.info('Backfilling thread visibility...')

    safety_assured do
      execute('UPDATE conversations SET public = true FROM (SELECT account_id, conversation_id FROM statuses WHERE NOT reply AND visibility IN (0, 1)) AS s WHERE conversations.id = s.conversation_id')
    end
  end

  def down
    true
  end
end
