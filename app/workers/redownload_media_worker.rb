# frozen_string_literal: true

class RedownloadMediaWorker
  include Sidekiq::Worker
  include ExponentialBackoff

  sidekiq_options queue: 'pull', retry: 3

  def perform(id)
    media_attachment = MediaAttachment.find(id)

    return if media_attachment.remote_url.blank?

    orig_small_url = media_attachment.file.url(:small)

    media_attachment.download_file!
    media_attachment.download_thumbnail!

    if media_attachment.save && media_attachment.inline? && media_attachment.status.present?
      if unsupported_media_type?(media_attachment.file.content_type)
        media_attachment.destroy
        true
      else
        media_attachment.status.text.gsub!("#{orig_small_url}##{media_attachment.id}", media_attachment.file.url(:small))
        media_attachment.status.save
      end
    end
  rescue ActiveRecord::RecordNotFound
    true
  end

  private

  def unsupported_media_type?(mime_type)
    mime_type.present? && !MediaAttachment.supported_mime_types.include?(mime_type)
  end
end
