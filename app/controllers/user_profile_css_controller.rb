# frozen_string_literal: true

class UserProfileCssController < ApplicationController
  skip_before_action :store_current_location
  skip_before_action :require_functional!

  before_action :set_cache_headers
  before_action :set_account

  def show
    expires_in 3.minutes, public: true
    render plain: css, content_type: 'text/css'
  end

  private

  def css
    @account.user&.setting_style_css_profile_errors.blank? ? (@account.user&.setting_style_css_profile || '') : ''
  end

  def set_account
    @account = Account.find(params[:id])
  end
end
