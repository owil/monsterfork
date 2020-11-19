# frozen_string_literal: true

module CommandTag::Commands
  def self.included(base)
    Dir[File.join(__dir__, 'commands', '*.rb')].sort.each do |file|
      require file
      base.include(CommandTag::Commands.const_get(File.basename(file).gsub('.rb', '').split('_').map(&:capitalize).join))
    end
  end
end
