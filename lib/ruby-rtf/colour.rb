module RubyRTF
  # Holds information about a colour
  class Colour
    # @return [Integer] The red value
    attr_accessor :red

    # @return [Integer] The green value
    attr_accessor :green

    # @return [Integer] The blue value
    attr_accessor :blue

    # @return [Integer] The shade value
    attr_accessor :shade

    # @return [Integer] The tint value
    attr_accessor :tint

    # @return [Symbol] The theme information
    attr_accessor :theme

    # @return [Boolean] True if reader should use it's default colour
    attr_accessor :use_default
    alias :use_default? :use_default

    # Create a new colour
    #
    # @param red [Integer] Red value between 0 and 255 (default: 0)
    # @param green [Integer] Green value between 0 and 255 (default: 0)
    # @param blue [Integer] Blue value between 0 and 255 (default: 0)
    # @return [RubyRTF::Colour] New colour object
    def initialize(red = 0, green = 0, blue = 0)
      @red = red
      @green = green
      @blue = blue
      @use_default = false
    end

    # Convert the colour to a string
    #
    # @return [String] The string representation of the colour
    def to_s
      return "default" if use_default?
      "[#{red}, #{green}, #{blue}]"
    end
  end

  # Alias the Colour class as Color
  Color = Colour
end