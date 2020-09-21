class RemoveSemiprivateFlag < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      remove_column :statuses, :semiprivate
    end
  end
end
