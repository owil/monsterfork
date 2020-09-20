class BackfillCustomEmojiOwnership < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    site_contact = Account.site_contact
    CustomEmoji.local.in_batches.update_all(account_id: site_contact.id)
  end

  def down
    nil
  end
end
