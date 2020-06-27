# frozen_string_literal: true

class Settings::Preferences::FiltersController < Settings::PreferencesController
  private

  def after_update_redirect_path
    settings_preferences_filters_path
  end
end
