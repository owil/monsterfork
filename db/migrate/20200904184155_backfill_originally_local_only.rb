class BackfillOriginallyLocalOnly < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      execute('UPDATE statuses SET originally_local_only = false WHERE originally_local_only IS NULL')
      execute('UPDATE statuses SET originally_local_only = true WHERE local_only')
    end
  end

  def down
    nil
  end
end
