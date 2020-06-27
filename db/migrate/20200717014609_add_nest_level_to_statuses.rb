class AddNestLevelToStatuses < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_column :statuses, :nest_level, :integer, limit: 1, null: false, default: 0
    end
  end
end
