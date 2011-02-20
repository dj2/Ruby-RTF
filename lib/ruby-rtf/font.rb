module RubyRTF
  # Holds the information for a given font
  class Font
    attr_accessor :name, :family_command

    alias :to_s :name
  end
end