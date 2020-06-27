class DropPublishingDelay < ActiveRecord::Migration[5.2]
  def change
    drop_table :publishing_delays
  end
end
