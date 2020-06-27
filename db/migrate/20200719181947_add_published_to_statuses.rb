class AddPublishedToStatuses < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_column :statuses, :published, :boolean, default: true, null: false
    end
  end
end
