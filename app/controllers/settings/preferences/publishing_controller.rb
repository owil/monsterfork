# frozen_string_literal: true

class Settings::Preferences::PublishingController < Settings::PreferencesController
  private

  def after_update_redirect_path
    settings_preferences_publishing_path
  end
end
