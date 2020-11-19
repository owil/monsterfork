# frozen_string_literal: true

module CommandTag::Commands::HelloWorld
  def handle_helloworld_startup
    @vars['hello_world'] = ['Hello, world!']
  end

  def handle_hello_world_with_return(_)
    'Hello, world!'
  end
end
