class AddOriginallyLocalOnlyToStatuses < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_column :statuses, :originally_local_only, :boolean, default: false, null: false
    end
  end
end
