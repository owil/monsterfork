# frozen_string_literal: true

class Settings::Preferences::PrivacyController < Settings::PreferencesController
  private

  def after_update_redirect_path
    settings_preferences_privacy_path
  end
end
