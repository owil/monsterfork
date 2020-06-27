# frozen_string_literal: true

class REST::PreferencesSerializer < ActiveModel::Serializer
  attribute :posting_default_privacy, key: 'posting:default:visibility'
  attribute :posting_default_sensitive, key: 'posting:default:sensitive'
  attribute :posting_default_language, key: 'posting:default:language'

  attribute :reading_default_sensitive_media, key: 'reading:expand:media'
  attribute :reading_default_sensitive_text, key: 'reading:expand:spoilers'

  attribute :posting_default_manual_publish, key: 'posting:default:manual_publish'

  def posting_default_privacy
    object.user.setting_default_privacy
  end

  def posting_default_sensitive
    object.user.setting_default_sensitive
  end

  def posting_default_language
    object.user.setting_default_language.presence
  end

  def reading_default_sensitive_media
    object.user.setting_display_media
  end

  def reading_default_sensitive_text
    object.user.setting_expand_spoilers
  end

  def posting_default_manual_publish
    object.user.setting_manual_publish
  end
end
