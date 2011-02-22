module RubyRTF
  # Holds the information for a given font
  class Font
    # @return [Integer] The font numberb
    attr_accessor :number

    # @return [String] The font name
    attr_accessor :name

    # @return [String] The alternate name for this font
    attr_accessor :alternate_name

    # @return [String] The panose number for the font
    attr_accessor :panose

    # @return [Symbol] The theme for this font
    attr_accessor :theme

    # @return [Symbol] The pitch information for this font
    attr_accessor :pitch

    # @return [Integer] The character set number for the font
    attr_accessor :character_set

    # @return [String] The non-tagged name for the font
    attr_accessor :non_tagged_name

    # @return [Symbol] The font family command
    attr_accessor :family_command

    # The font families
    FAMILIES = [:nil, :roman, :swiss, :modern, :script, :decor, :tech, :bldl]

    # The font pitch values
    PITCHES = [:default, :fixed, :variable]

    # Creates a new font
    #
    # @param name [String] The font name to set (default: '')
    # @return [RubyRTF::Font] The new font
    def initialize(name = '')
      @family_command = :nil
      @name = name
      @alternate_name = ''
      @non_tagged_name = ''
      @panose = ''
    end

    # Set the pitch value for the font
    #
    # @param val [Integer] The pitch value to set (0, 1, or 2)
    # @return [Nil]
    def pitch=(val)
      @pitch = PITCHES[val]
    end

    # Cleans up the various font names
    #
    # @return [Nil]
    def cleanup_names
      @name = cleanup_name(@name)
      @alternate_name = cleanup_name(@alternate_name)
      @non_tagged_name = cleanup_name(@non_tagged_name)
    end

    # Convert to string format
    #
    # @return [String] The string representation
    def to_s
      "#{number}: #{name}"
    end

    private

    # Cleanups up a given font name
    #
    # @param str [String] The font name to cleanup
    # @return [String] The cleaned font name
    def cleanup_name(str)
      str.gsub(/;$/, '')
    end
  end
end
