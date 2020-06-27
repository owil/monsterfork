class DropDestructingStatus < ActiveRecord::Migration[5.2]
  def change
    drop_table :destructing_statuses
  end
end
