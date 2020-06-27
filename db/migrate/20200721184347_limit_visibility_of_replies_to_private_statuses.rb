class LimitVisibilityOfRepliesToPrivateStatuses < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    Status.includes(:thread).where.not(visibility: :direct).where(reply: true).where('statuses.in_reply_to_account_id != statuses.account_id').find_each do |status|
      status.update!(visibility: status.thread.visibility) unless status.thread.nil? || %w(public unlisted).include?(status.thread.visibility) || ['direct', 'limited', status.thread.visibility].include?(status.visibility)
    end
  end

  def down
    true
  end
end
