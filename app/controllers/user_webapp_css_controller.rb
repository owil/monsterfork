# frozen_string_literal: true

class UserWebappCssController < ApplicationController
  skip_before_action :store_current_location
  skip_before_action :require_functional!

  before_action :set_account

  def show
    render plain: css, content_type: 'text/css'
  end

  private

  def css_dashed_nest
    return unless @account.user&.setting_style_dashed_nest

    %(
      div[data-nest-level]
      { border-style: dashed; }
    )
  end

  def css_underline_a
    return unless @account.user&.setting_style_underline_a

    %(
      .status__content__text a,
      .reply-indicator__content a,
      .composer--reply > .content a,
      .account__header__content a
      { text-decoration: underline; }

      .status__content__text a:hover,
      .reply-indicator__content a:hover,
      .composer--reply > .content a:hover,
      .account__header__content a:hover
      { text-decoration: none; }
    )
  end

  def css_wide_media
    return unless @account.user&.setting_style_wide_media

    %(
      .media-gallery
      { height: auto !important; }

      .media-gallery__item
      { width: 100% !important; }

      .spoiler-button + .media-gallery__item
      { height: 5em !important; }

      .spoiler-button--minified + .media-gallery__item
      { height: 280px !important; }
    )
  end

  def css_lowercase
    return unless @account.user&.setting_style_lowercase

    %(
      div, button, span
      { text-transform: lowercase; }

      code, pre
      { text-transform: initial !important; }
    )
  end

  def css_webapp
    @account.user&.setting_style_css_webapp_errors.blank? ? (@account.user&.setting_style_css_webapp || '') : ''
  end

  def css
    "#{css_dashed_nest}\n#{css_underline_a}\n#{css_wide_media}\n#{css_lowercase}\n#{css_webapp}".squish
  end

  def set_account
    @account = Account.find(params[:id])
  end
end
