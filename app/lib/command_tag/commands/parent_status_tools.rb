# frozen_string_literal: true
module CommandTag::Commands::ParentStatusTools
  def handle_publish_once_at_end(_)
    is_blank = status_text_blank?
    return PublishStatusService.new.call(@status) if @parent.blank? || !is_blank
    return unless is_blank && author_of_parent? && !@parent.published?

    PublishStatusService.new.call(@parent)
  end

  alias handle_publish_post_once_at_end                   handle_publish_once_at_end
  alias handle_publish_roar_once_at_end                   handle_publish_once_at_end
  alias handle_publish_toot_once_at_end                   handle_publish_once_at_end

  def handle_edit_once_before_save(_)
    return unless author_of_parent?

    params = @parent.slice(*UpdateStatusService::ALLOWED_ATTRIBUTES).with_indifferent_access.compact
    params[:text] = @text
    UpdateStatusService.new.call(@parent, params)
    destroy_status!
  end

  alias handle_edit_post_once_before_save                 handle_edit_once_before_save
  alias handle_edit_roar_once_before_save                 handle_edit_once_before_save
  alias handle_edit_toot_once_before_save                 handle_edit_once_before_save
  alias handle_edit_parent_once_before_save               handle_edit_once_before_save

  def handle_mute_once_at_end(_)
    return if author_of_parent?

    MuteStatusService.new.call(@account, @parent)
  end

  alias handle_mute_post_once_at_end                      handle_mute_once_at_end
  alias handle_mute_roar_once_at_end                      handle_mute_once_at_end
  alias handle_mute_toot_once_at_end                      handle_mute_once_at_end
  alias handle_mute_parent_once_at_end                    handle_mute_once_at_end
  alias handle_hide_once_at_end                           handle_mute_once_at_end
  alias handle_hide_post_once_at_end                      handle_mute_once_at_end
  alias handle_hide_roar_once_at_end                      handle_mute_once_at_end
  alias handle_hide_toot_once_at_end                      handle_mute_once_at_end
  alias handle_hide_parent_once_at_end                    handle_mute_once_at_end

  def handle_unmute_once_at_end(_)
    return if author_of_parent?

    @account.unmute_status!(@parent)
  end

  alias handle_unmute_post_once_at_end                    handle_unmute_once_at_end
  alias handle_unmute_roar_once_at_end                    handle_unmute_once_at_end
  alias handle_unmute_toot_once_at_end                    handle_unmute_once_at_end
  alias handle_unmute_parent_once_at_end                  handle_unmute_once_at_end
  alias handle_unhide_once_at_end                         handle_unmute_once_at_end
  alias handle_unhide_post_once_at_end                    handle_unmute_once_at_end
  alias handle_unhide_roar_once_at_end                    handle_unmute_once_at_end
  alias handle_unhide_toot_once_at_end                    handle_unmute_once_at_end
  alias handle_unhide_parent_once_at_end                  handle_unmute_once_at_end

  def handle_mute_thread_once_at_end(_)
    return if author_of_parent?

    MuteConversationService.new.call(@account, @conversation)
  end

  alias handle_mute_conversation_once_at_end              handle_mute_thread_once_at_end
  alias handle_hide_thread_once_at_end                    handle_mute_thread_once_at_end
  alias handle_hide_conversation_once_at_end              handle_mute_thread_once_at_end

  def handle_unmute_thread_once_at_end(_)
    return if author_of_parent? || @conversation.blank?

    @account.unmute_conversation!(@conversation)
  end

  alias handle_unmute_conversation_once_at_end            handle_unmute_thread_once_at_end
  alias handle_unhide_thread_once_at_end                  handle_unmute_thread_once_at_end
  alias handle_unhide_conversation_once_at_end            handle_unmute_thread_once_at_end
end
