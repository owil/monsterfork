class AddTitleToStatuses < ActiveRecord::Migration[5.2]
  def change
    add_column :statuses, :title, :text
  end
end
