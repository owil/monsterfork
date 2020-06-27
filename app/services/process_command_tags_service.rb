# frozen_string_literal: true

class ProcessCommandTagsService < BaseService
  def call(account, status, raise_if_no_output: true)
    CommandTag::Processor.new(account, status).process!
    raise Mastodon::LengthValidationError, 'Text commands were processed successfully.' if raise_if_no_output && status.destroyed?

    status
  end
end
