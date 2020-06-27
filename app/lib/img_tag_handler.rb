# frozen_string_literal: true

class ImgTagHandler < ::Ox::Sax
  attr_reader :srcs
  attr_reader :alts

  def initialize
    @stack = []
    @srcs = []
    @alts = {}
  end

  def start_element(element_name)
    @stack << [element_name, {}]
  end

  def end_element(_)
    self_name, self_attributes = @stack[-1]
    if self_name == :img && !self_attributes[:src].nil?
      @srcs << self_attributes[:src]
      @alts[self_attributes[:src]] = self_attributes[:alt]&.strip
    end
    @stack.pop
  end

  def attr(attribute_name, attribute_value)
    _name, attributes = @stack.last
    attributes[attribute_name] = attribute_value&.strip
  end
end
