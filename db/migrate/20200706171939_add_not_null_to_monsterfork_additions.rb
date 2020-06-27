class AddNotNullToMonsterforkAdditions < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      Rails.logger.info("Setting NOT NULL on domain_allows.hidden")
      change_column_null :domain_allows, :hidden, false

      Rails.logger.info("Setting NOT NULL on statuses.edited")
      change_column_null :statuses, :edited, false
    end
  end
end
