# frozen_string_literal: true

class Form::CustomEmojiBatch
  include ActiveModel::Model
  include Authorization
  include AccountableConcern

  attr_accessor :custom_emoji_ids, :action, :current_account,
                :category_id, :category_name, :visible_in_picker

  def save
    case action
    when 'update'
      update!
    when 'list'
      list!
    when 'unlist'
      unlist!
    when 'enable'
      enable!
    when 'disable'
      disable!
    when 'copy'
      copy!
    when 'delete'
      delete!
    when 'claim'
      claim!
    when 'unclaim'
      unclaim!
    end
  end

  private

  def custom_emojis(include_all = false)
    @custom_emojis ||= (include_all || current_account&.user&.staff? ? CustomEmoji.where(id: custom_emoji_ids) : CustomEmoji.local.where(id: custom_emoji_ids, account: current_account))
  end

  def update!
    custom_emojis.each { |custom_emoji| authorize(custom_emoji, :update?) }

    category = begin
      if category_id.present?
        CustomEmojiCategory.find(category_id)
      elsif category_name.present?
        CustomEmojiCategory.find_or_create_by!(name: current_account&.user&.staff? ? category_name.strip : "(@#{current_account.username}) #{category_name}".rstrip)
      end
    end

    return if category.name.start_with?('(@') && !category.name.start_with?("(@#{current_account.username}) ")

    custom_emojis.each do |custom_emoji|
      custom_emoji.update(category_id: category&.id)
      log_action :update, custom_emoji
    end
  end

  def list!
    custom_emojis.each { |custom_emoji| authorize(custom_emoji, :update?) }

    custom_emojis.each do |custom_emoji|
      custom_emoji.update(visible_in_picker: true)
      log_action :update, custom_emoji
    end
  end

  def unlist!
    custom_emojis.each { |custom_emoji| authorize(custom_emoji, :update?) }

    custom_emojis.each do |custom_emoji|
      custom_emoji.update(visible_in_picker: false)
      log_action :update, custom_emoji
    end
  end

  def enable!
    custom_emojis.each { |custom_emoji| authorize(custom_emoji, :enable?) }

    custom_emojis.each do |custom_emoji|
      custom_emoji.update(disabled: false)
      log_action :enable, custom_emoji
    end
  end

  def disable!
    custom_emojis.each { |custom_emoji| authorize(custom_emoji, :disable?) }

    custom_emojis.each do |custom_emoji|
      custom_emoji.update(disabled: true)
      log_action :disable, custom_emoji
    end
  end

  def copy!
    custom_emojis(true).each { |custom_emoji| authorize(custom_emoji, :copy?) }

    custom_emojis.each do |custom_emoji|
      copied_custom_emoji = custom_emoji.copy!(current_account)
      log_action :create, copied_custom_emoji
    end
  end

  def delete!
    custom_emojis.each { |custom_emoji| authorize(custom_emoji, :destroy?) }

    custom_emojis.each do |custom_emoji|
      custom_emoji.destroy
      log_action :destroy, custom_emoji
    end
  end

  def claim!
    custom_emojis(true).each { |custom_emoji| authorize(custom_emoji, :claim?) }

    custom_emojis.each do |custom_emoji|
      if custom_emoji.local?
        custom_emoji.update(account: current_account)
        log_action :update, custom_emoji
      else
        copied_custom_emoji = custom_emoji.copy!(current_account)
        log_action :create, copied_custom_emoji
      end
    end
  end

  def unclaim!
    custom_emojis.each { |custom_emoji| authorize(custom_emoji, :unclaim?) }

    custom_emojis.each do |custom_emoji|
      custom_emoji.update(account: nil)
      log_action :update, custom_emoji
    end
  end
end
