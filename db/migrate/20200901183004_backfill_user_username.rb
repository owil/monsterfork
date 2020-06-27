class BackfillUserUsername < ActiveRecord::Migration[5.2]
  def up
    User.find_each do |user|
      user.update!(username: user.account.username)
    end
  end

  def down
    nil
  end
end
