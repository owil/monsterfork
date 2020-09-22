# frozen_string_literal: true

require 'w3c_validators'

class UserSettingsDecorator
  include W3CValidators

  attr_reader :user, :settings

  def initialize(user)
    @user = user
  end

  def update(settings)
    @settings = settings
    process_update
  end

  private

  def process_update
    user.settings['notification_emails'] = merged_notification_emails if change?('notification_emails')
    user.settings['interactions']        = merged_interactions if change?('interactions')
    user.settings['default_privacy']     = default_privacy_preference if change?('setting_default_privacy')
    user.settings['default_sensitive']   = default_sensitive_preference if change?('setting_default_sensitive')
    user.settings['default_language']    = default_language_preference if change?('setting_default_language')
    user.settings['unfollow_modal']      = unfollow_modal_preference if change?('setting_unfollow_modal')
    user.settings['boost_modal']         = boost_modal_preference if change?('setting_boost_modal')
    user.settings['favourite_modal']     = favourite_modal_preference if change?('setting_favourite_modal')
    user.settings['delete_modal']        = delete_modal_preference if change?('setting_delete_modal')
    user.settings['auto_play_gif']       = auto_play_gif_preference if change?('setting_auto_play_gif')
    user.settings['display_media']       = display_media_preference if change?('setting_display_media')
    user.settings['expand_spoilers']     = expand_spoilers_preference if change?('setting_expand_spoilers')
    user.settings['reduce_motion']       = reduce_motion_preference if change?('setting_reduce_motion')
    user.settings['system_font_ui']      = system_font_ui_preference if change?('setting_system_font_ui')
    user.settings['system_emoji_font']   = system_emoji_font_preference if change?('setting_system_emoji_font')
    user.settings['noindex']             = noindex_preference if change?('setting_noindex')
    user.settings['hide_followers_count'] = hide_followers_count_preference if change?('setting_hide_followers_count')
    user.settings['flavour']             = flavour_preference if change?('setting_flavour')
    user.settings['skin']                = skin_preference if change?('setting_skin')
    user.settings['hide_network']        = hide_network_preference if change?('setting_hide_network')
    user.settings['aggregate_reblogs']   = aggregate_reblogs_preference if change?('setting_aggregate_reblogs')
    user.settings['show_application']    = show_application_preference if change?('setting_show_application')
    user.settings['advanced_layout']     = advanced_layout_preference if change?('setting_advanced_layout')
    user.settings['default_content_type'] = default_content_type_preference if change?('setting_default_content_type')
    user.settings['use_blurhash']        = use_blurhash_preference if change?('setting_use_blurhash')
    user.settings['use_pending_items']   = use_pending_items_preference if change?('setting_use_pending_items')
    user.settings['trends']              = trends_preference if change?('setting_trends')
    user.settings['crop_images']         = crop_images_preference if change?('setting_crop_images')

    user.settings['manual_publish']      = manual_publish_preference if change?('setting_manual_publish')
    user.settings['style_dashed_nest']   = style_dashed_nest_preference if change?('setting_style_dashed_nest')
    user.settings['style_underline_a']   = style_underline_a_preference if change?('setting_style_underline_a')
    user.settings['style_css_profile']   = style_css_profile_preference if change?('setting_style_css_profile')
    user.settings['style_css_webapp']    = style_css_webapp_preference if change?('setting_style_css_webapp')
    user.settings['style_wide_media']    = style_wide_media_preference if change?('setting_style_wide_media')
    user.settings['publish_in']          = publish_in_preference if change?('setting_publish_in')
    user.settings['unpublish_in']        = unpublish_in_preference if change?('setting_unpublish_in')
    user.settings['unpublish_delete']    = unpublish_delete_preference if change?('setting_unpublish_delete')
    user.settings['boost_every']         = boost_every_preference if change?('setting_boost_every')
    user.settings['boost_jitter']        = boost_jitter_preference if change?('setting_boost_jitter')
    user.settings['boost_random']        = boost_random_preference if change?('setting_boost_random')
    user.settings['filter_from_unknown'] = filter_from_unknown_preference if change?('setting_filter_from_unknown')
    user.settings['unpublish_on_delete'] = unpublish_on_delete_preference if change?('setting_unpublish_on_delete')
    user.settings['rss_disabled']        = rss_disabled_preference if change?('setting_rss_disabled')
    user.settings['no_boosts_home']      = no_boosts_home_preference if change?('setting_no_boosts_home')
  end

  def merged_notification_emails
    user.settings['notification_emails'].merge coerced_settings('notification_emails').to_h
  end

  def merged_interactions
    user.settings['interactions'].merge coerced_settings('interactions').to_h
  end

  def default_privacy_preference
    settings['setting_default_privacy']
  end

  def default_sensitive_preference
    boolean_cast_setting 'setting_default_sensitive'
  end

  def unfollow_modal_preference
    boolean_cast_setting 'setting_unfollow_modal'
  end

  def boost_modal_preference
    boolean_cast_setting 'setting_boost_modal'
  end

  def favourite_modal_preference
    boolean_cast_setting 'setting_favourite_modal'
  end

  def delete_modal_preference
    boolean_cast_setting 'setting_delete_modal'
  end

  def system_font_ui_preference
    boolean_cast_setting 'setting_system_font_ui'
  end

  def system_emoji_font_preference
    boolean_cast_setting 'setting_system_emoji_font'
  end

  def auto_play_gif_preference
    boolean_cast_setting 'setting_auto_play_gif'
  end

  def display_media_preference
    settings['setting_display_media']
  end

  def expand_spoilers_preference
    boolean_cast_setting 'setting_expand_spoilers'
  end

  def reduce_motion_preference
    boolean_cast_setting 'setting_reduce_motion'
  end

  def noindex_preference
    boolean_cast_setting 'setting_noindex'
  end

  def hide_followers_count_preference
    boolean_cast_setting 'setting_hide_followers_count'
  end

  def flavour_preference
    settings['setting_flavour']
  end

  def skin_preference
    settings['setting_skin']
  end

  def hide_network_preference
    boolean_cast_setting 'setting_hide_network'
  end

  def show_application_preference
    boolean_cast_setting 'setting_show_application'
  end

  def default_language_preference
    settings['setting_default_language']
  end

  def aggregate_reblogs_preference
    boolean_cast_setting 'setting_aggregate_reblogs'
  end

  def advanced_layout_preference
    boolean_cast_setting 'setting_advanced_layout'
  end

  def default_content_type_preference
    settings['setting_default_content_type']
  end

  def use_blurhash_preference
    boolean_cast_setting 'setting_use_blurhash'
  end

  def use_pending_items_preference
    boolean_cast_setting 'setting_use_pending_items'
  end

  def trends_preference
    boolean_cast_setting 'setting_trends'
  end

  def crop_images_preference
    boolean_cast_setting 'setting_crop_images'
  end

  def manual_publish_preference
    boolean_cast_setting 'setting_manual_publish'
  end

  def style_dashed_nest_preference
    boolean_cast_setting 'setting_style_dashed_nest'
  end

  def style_underline_a_preference
    boolean_cast_setting 'setting_style_underline_a'
  end

  def style_css_profile_preference
    css = settings['setting_style_css_profile'].to_s.strip.delete("\r").gsub(/\n\n\n+/, "\n\n")
    user.settings['style_css_profile_errors'] = validate_css(css)
    css
  end

  def style_css_webapp_preference
    css = settings['setting_style_css_webapp'].to_s.strip.delete("\r").gsub(/\n\n\n+/, "\n\n")
    user.settings['style_css_webapp_errors'] = validate_css(css)
    css
  end

  def style_wide_media_preference
    boolean_cast_setting 'setting_style_wide_media'
  end

  def publish_in_preference
    settings['setting_publish_in'].to_i
  end

  def unpublish_in_preference
    settings['setting_unpublish_in'].to_i
  end

  def unpublish_delete_preference
    boolean_cast_setting 'setting_unpublish_delete'
  end

  def boost_every_preference
    settings['setting_boost_every'].to_i
  end

  def boost_jitter_preference
    settings['setting_boost_jitter'].to_i
  end

  def boost_random_preference
    boolean_cast_setting 'setting_boost_random'
  end

  def filter_from_unknown_preference
    boolean_cast_setting 'setting_filter_from_unknown'
  end

  def unpublish_on_delete_preference
    boolean_cast_setting 'setting_unpublish_on_delete'
  end

  def rss_disabled_preference
    boolean_cast_setting 'setting_rss_disabled'
  end

  def no_boosts_home_preference
    boolean_cast_setting 'setting_no_boosts_home'
  end

  def boolean_cast_setting(key)
    ActiveModel::Type::Boolean.new.cast(settings[key])
  end

  def coerced_settings(key)
    coerce_values settings.fetch(key, {})
  end

  def coerce_values(params_hash)
    params_hash.transform_values { |x| ActiveModel::Type::Boolean.new.cast(x) }
  end

  def change?(key)
    !settings[key].nil?
  end

  def validate_css(css)
    @validator ||= CSSValidator.new
    results = @validator.validate_text(css)
    results.errors.map { |e| e.to_s.strip }
  end
end
