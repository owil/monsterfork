class AddCuratedToStatuses < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_column :statuses, :curated, :boolean, default: false, null: false
    end
  end
end
