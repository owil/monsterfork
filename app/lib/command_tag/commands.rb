# frozen_string_literal: true

Dir[File.join(__dir__, 'command', '*.rb')].sort.each { |file| require file }

module CommandTag::Commands
  def self.included(base)
    CommandTag::Command.constants.map(&CommandTag::Command.method(:const_get)).grep(Module) do |mod|
      base.include(mod)
    end
  end
end
