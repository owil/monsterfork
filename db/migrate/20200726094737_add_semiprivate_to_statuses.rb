class AddSemiprivateToStatuses < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_column :statuses, :semiprivate, :boolean, default: false, null: false
    end
  end
end
