class BackfillRootToConversations < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    Rails.logger.info("Adding URI to statuses without one...")
    Status.where(uri: nil).or(Status.where(uri: '')).find_each do |status|
      status.update(uri: ActivityPub::TagManager.instance.uri_for(status))
    end

    Rails.logger.info('Setting root of all conversations...')
    safety_assured do
      execute('UPDATE conversations SET root = s.uri FROM (SELECT conversation_id, uri FROM statuses WHERE NOT reply) AS s WHERE conversations.id = s.conversation_id')
    end
  end

  def down
    true
  end
end
