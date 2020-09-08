# frozen_string_literal: true

class Matrix::BaseController < ApplicationController
  include RateLimitHeaders

  skip_before_action :store_current_location
  skip_before_action :require_functional!

  before_action :set_cache_headers

  protect_from_forgery with: :null_session

  skip_around_action :set_locale

  rescue_from ActiveRecord::RecordInvalid, Mastodon::ValidationError do |e|
    render json: { success: false, error: e.to_s }, status: 422
  end

  rescue_from ActiveRecord::RecordNotUnique do
    render json: { success: false, error: 'Duplicate record' }, status: 422
  end

  rescue_from ActiveRecord::RecordNotFound do
    render json: { success: false, error: 'Record not found' }, status: 404
  end

  rescue_from HTTP::Error, Mastodon::UnexpectedResponseError do
    render json: { success: false, error: 'Remote data could not be fetched' }, status: 503
  end

  rescue_from OpenSSL::SSL::SSLError do
    render json: { success: false, error: 'Remote SSL certificate could not be verified' }, status: 503
  end

  rescue_from Mastodon::NotPermittedError do
    render json: { success: false, error: 'This action is not allowed' }, status: 403
  end

  rescue_from Mastodon::RaceConditionError do
    render json: { success: false, error: 'There was a temporary problem serving your request, please try again' }, status: 503
  end

  rescue_from Mastodon::RateLimitExceededError do
    render json: { auth: { success: false }, success: false, error: I18n.t('errors.429') }, status: 429
  end

  rescue_from ActionController::ParameterMissing do |e|
    render json: { success: false, error: e.to_s }, status: 400
  end

  def doorkeeper_unauthorized_render_options(error: nil)
    { json: { success: false, error: (error.try(:description) || 'Not authorized') } }
  end

  def doorkeeper_forbidden_render_options(*)
    { json: { success: false, error: 'This action is outside the authorized scopes' } }
  end

  protected

  def current_resource_owner
    @current_user ||= User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
  end

  def current_user
    current_resource_owner || super
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def require_authenticated_user!
    render json: { success: false, error: 'This method requires an authenticated user' }, status: 401 unless current_user
  end

  def require_user!
    if !current_user
      render json: { success: false, error: 'This method requires an authenticated user' }, status: 422
    elsif current_user.disabled?
      render json: { success: false, error: 'Your login is currently disabled' }, status: 403
    elsif !current_user.confirmed?
      render json: { success: false, error: 'Your login is missing a confirmed e-mail address' }, status: 403
    elsif !current_user.approved?
      render json: { success: false, error: 'Your login is currently pending approval' }, status: 403
    else
      set_user_activity
    end
  end

  def render_empty
    render json: {}, status: 200
  end

  def authorize_if_got_token!(*scopes)
    doorkeeper_authorize!(*scopes) if doorkeeper_token
  end

  def set_cache_headers
    response.headers['Cache-Control'] = 'no-cache, no-store, max-age=0, must-revalidate'
  end
end
