# frozen_string_literal: true

class ActivityPub::OutboxSerializer < ActivityPub::CollectionSerializer
  def self.serializer_for(model, options)
    if model.class.name == 'ActivityPub::ActivityPresenter'
      ActivityPub::ActivitySerializer
    else
      super
    end
  end

  def items
    object.items.map { |status| ActivityPub::ActivityPresenter.from_status(status, instance_options[:domain], embed: true) }
  end
end
