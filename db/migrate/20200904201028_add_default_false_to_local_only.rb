class AddDefaultFalseToLocalOnly < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      change_column :statuses, :local_only, :boolean, default: false, null: false
    end
  end
end
