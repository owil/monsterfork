class AddInlineToMediaAttachments < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_column :media_attachments, :inline, :boolean, default: false, null: false
    end
  end
end
