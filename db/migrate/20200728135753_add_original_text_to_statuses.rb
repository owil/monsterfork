class AddOriginalTextToStatuses < ActiveRecord::Migration[5.2]
  def change
    add_column :statuses, :original_text, :text
  end
end
