class AddTimelinesOnlyToMute < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_column :mutes, :timelines_only, :boolean, default: false, null: false
    end
  end
end
