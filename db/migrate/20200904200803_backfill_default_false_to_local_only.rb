class BackfillDefaultFalseToLocalOnly < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      execute('UPDATE statuses SET local_only = false WHERE local_only IS NULL')
    end
  end

  def down
    nil
  end
end
