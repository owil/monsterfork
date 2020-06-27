class AddStickyToAccountDomainPermissions < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_column :account_domain_permissions, :sticky, :boolean, default: false, null: false
    end
  end
end
