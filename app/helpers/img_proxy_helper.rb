# frozen_string_literal: true

#                  .~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~.                  #
###################              Cthulhu Code!              ###################
#                  `~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`                  #
# - Has a high complexity level and needs tests.                              #
# - Makes many assumptions the environment it's included into.                #
# - Incurs a high performance penalty.                                        #
#                                                                             #
###############################################################################

module ImgProxyHelper
  def process_inline_images!
    raise NameError('@status must be defined by the instance this method is being called from.') unless defined?(@status)
    return if @status.text&.strip.blank? || @status.content_type == 'text/plain'

    replace_markdown_images_with_html!

    handler = ImgTagHandler.new
    Ox.sax_parse(handler, StringIO.new(@status.text, 'r'))
    return if handler.srcs.blank?

    @skip_download_from = { @status.account.domain => DomainBlock.reject_media?(@status.account.domain) }
    @redownload_attachment_ids = Set[]

    handler.srcs.each do |src|
      alt                   = handler.alts[src]
      normalized_src_parts  = begin
                                Addressable::URI.parse(src&.strip).normalize
                              rescue Addressable::URI::InvalidURIError
                                nil
                              end
      normalized_src        = normalized_src_parts.to_s

      next replace_text!(src) if normalized_src.blank? || skip_download_from?(normalized_src_parts.host)

      file_name             = normalized_src_parts.path.split('/').last
      media_attachment      = find_media_attachment(normalized_src, file_name)

      if media_attachment.present?
        media_attachment.update(description: alt) if alt_more_descriptive?(alt, media_attachment.description)
      elsif normalized_src_parts.scheme.blank? || !file_name.match?(/\S\.\w{3,}/)
        next replace_text!(src)
      else
        media_attachment = create_media_attachment!(normalized_src, alt)
      end

      next replace_text!(src) if media_attachment.blank? || media_attachment.destroyed?

      if media_attachment.needs_redownload?
        replace_text!(src, "#{media_attachment.file.url(:small)}##{media_attachment.id}")
      else
        replace_text!(src, media_attachment.file.url(:small))
      end
    end
  end

  private

  def skip_download_from?(domain)
    return true if @skip_download_from[@status.account.domain]
    return @skip_download_from[domain] if @skip_download_from[domain]

    @skip_download_from[domain] = DomainBlock.reject_media?(domain)
  end

  def unsupported_media_type?(mime_type)
    mime_type.present? && !MediaAttachment.supported_mime_types.include?(mime_type)
  end

  def html_entities
    @html_entities ||= HTMLEntities.new
  end

  def replace_markdown_images_with_html!
    return unless @status.content_type == 'text/markdown'

    @status.text.gsub!(/!\[(\S+)\]\(\s*(\S+)\s*\)/) do
      begin
        alt = html_entities.encode(Regexp.last_match(1).strip)
        url = Addressable::URI.parse(Regexp.last_match(2)).normalize.to_s
        "<img title=\"#{alt}\" alt=\"#{alt}\" src=\"#{url}\" />"
      rescue Addressable::URI::InvalidURIError
        ''
      end
    end
  end

  def replace_text!(text, replacement = '')
    @status.text.gsub!(text, replacement)
  end

  def alt_more_descriptive?(alt, description)
    return false unless alt.present? && description != alt
    return true if description.blank? || alt.split(/[\s\n\r]+/).count > description.split(/[\s\n\r]+/).count
  end

  def find_media_attachment(src, file_name)
    media_attachment = src.start_with?('http') ? MediaAttachment.find_by(account: @account, remote_url: src, inline: true) : nil
    return media_attachment if media_attachment.present?

    MediaAttachment.where(account: @status.account, file_file_name: file_name, inline: true)
                   .find { |m| [m.file.url(:small), m.file.url(:original)].include?(src) || m.status_id == @status.id }
  end

  def create_media_attachment!(src, alt)
    media_attachment = MediaAttachment.create!(account: @status.account, remote_url: src, description: alt, focus: nil, inline: true)
    media_attachment = process_media_attachment!(media_attachment)
    return if media_attachment.destroyed?

    @status.inlined_attachments.first_or_create!(media_attachment: media_attachment)
    media_attachment
  end

  def process_media_attachment!(media_attachment)
    media_attachment.download_file!
    media_attachment.download_thumbnail!
    media_attachment.save!
    media_attachment.destroy! if unsupported_media_type?(media_attachment.file.content_type)
    media_attachment
  rescue Mastodon::UnexpectedResponseError, HTTP::TimeoutError, HTTP::ConnectionError, OpenSSL::SSL::SSLError
    return if @redownload_attachment_ids.include?(media_attachment.id)

    RedownloadMediaWorker.perform_in(rand(30..60).seconds, media_attachment.id)
    @redownload_attachment_ids << media_attachment.id
    media_attachment
  end
end
