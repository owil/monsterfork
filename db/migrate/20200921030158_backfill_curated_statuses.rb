class BackfillCuratedStatuses < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    Status.with_public_visibility.joins(:status_stat).where('favourites_count != 0 OR reblogs_count != 0').in_batches.update_all(curated: true)
    Status.with_public_visibility.where(curated: false).left_outer_joins(:bookmarks).where.not(bookmarks: { status_id: nil }).in_batches.update_all(curated: true)
  end

  def down
    nil
  end
end
