module RubyRTF
  # Holds the information for a given font
  class Font
    # @return [String] The font name
    attr_accessor :name

    # @return [Symbol] The font family command
    attr_accessor :family_command

    alias :to_s :name
  end
end