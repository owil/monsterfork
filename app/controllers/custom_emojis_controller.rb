# frozen_string_literal: true

class CustomEmojisController < ApplicationController
  include Authorization
  include AccountableConcern

  layout 'admin'

  before_action :authenticate_user!
  before_action :set_pack
  before_action :set_body_classes

  def index
    authorize :custom_emoji, :index?

    @custom_emojis = filtered_custom_emojis.eager_load(:local_counterpart).page(params[:page])
    @form          = Form::CustomEmojiBatch.new
  end

  def new
    authorize :custom_emoji, :create?

    @custom_emoji = CustomEmoji.new(account: current_account)
  end

  def create
    authorize :custom_emoji, :create?

    @custom_emoji = CustomEmoji.new(resource_params.merge(account: current_account))

    if @custom_emoji.save
      log_action :create, @custom_emoji
      redirect_to custom_emojis_path, notice: I18n.t('admin.custom_emojis.created_msg')
    else
      render :new
    end
  end

  def batch
    @form = Form::CustomEmojiBatch.new(form_custom_emoji_batch_params.merge(current_account: current_account, action: action_from_button))
    @form.save
  rescue ActionController::ParameterMissing
    flash[:alert] = I18n.t('admin.accounts.no_account_selected')
  rescue Mastodon::NotPermittedError
    flash[:alert] = I18n.t('admin.custom_emojis.not_permitted')
  ensure
    redirect_to custom_emojis_path(filter_params)
  end

  private

  def resource_params
    params.require(:custom_emoji).permit(:shortcode, :image, :visible_in_picker)
  end

  def filtered_custom_emojis
    CustomEmojiFilter.new(filter_params, current_account).results
  end

  def filter_params
    params.slice(:page, *CustomEmojiFilter::KEYS).permit(:page, *CustomEmojiFilter::KEYS)
  end

  def action_from_button
    if params[:update]
      'update'
    elsif params[:list]
      'list'
    elsif params[:unlist]
      'unlist'
    elsif params[:enable]
      'enable'
    elsif params[:disable]
      'disable'
    elsif params[:copy]
      'copy'
    elsif params[:delete]
      'delete'
    elsif params[:claim]
      'claim'
    elsif params[:unclaim]
      'unclaim'
    end
  end

  def form_custom_emoji_batch_params
    params.require(:form_custom_emoji_batch).permit(:action, :category_id, :category_name, custom_emoji_ids: [])
  end

  def set_pack
    use_pack 'settings'
  end

  def set_body_classes
    @body_classes = 'admin'
  end
end
