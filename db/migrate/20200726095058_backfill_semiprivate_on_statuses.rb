class BackfillSemiprivateOnStatuses < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    Rails.logger.info('Backfilling semiprivate statuses...')
    safety_assured do
      Status.where(id: StatusDomainPermission.select(:status_id).distinct(:status_id)).in_batches.update_all(semiprivate: true)
    end
  end

  def down
    true
  end
end
