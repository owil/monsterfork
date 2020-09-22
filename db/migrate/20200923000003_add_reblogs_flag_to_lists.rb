class AddReblogsFlagToLists < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_column :lists, :reblogs, :boolean, default: false, null: false
      add_index :lists, :id, name: :lists_reblog_feeds, where: '(reblogs = TRUE)'
    end
  end
end
