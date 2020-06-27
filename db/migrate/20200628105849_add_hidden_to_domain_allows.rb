class AddHiddenToDomainAllows < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_column :domain_allows, :hidden, :boolean, default: false, allow_null: false
    end
  end
end
