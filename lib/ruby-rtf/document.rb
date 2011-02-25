module RubyRTF
  # Represents the entire RTF document
  class Document
    # @return [Array] The font table
    attr_reader :font_table

    # @return [Array] The colour table
    attr_reader :colour_table
    alias :color_table :colour_table

    # @return [Integer] The default font number for the document
    attr_accessor :default_font

    # @return [String] The characgter set for the document (:ansi, :pc, :pca, :mac)
    attr_accessor :character_set

    # @return [Array] The different formatted sections of the document
    attr_reader :sections

    # Creates a new document
    #
    # @return [RubyRTF::Document] The new document
    def initialize(sections)
      @font_table = []
      @colour_table = []
      @character_set = :ansi
      @default_font = 0

      @sections = sections
    end

    # Convert RubyRTF::Document to a string
    #
    # @return [String] String version of the document
    def to_s
      str = "RTF Document:\n" +
            "  Font Table:\n"

      font_table.each_with_index do |font, idx|
        next if font.nil?
        str << "    #{idx}: #{font}\n"
      end

      str << "  Colour Table:\n"
      colour_table.each_with_index do |colour, idx|
        str << "    #{idx}: #{colour}\n"
      end

      str << "  Body:\n\n"
      sections.each do |section|
        str << "#{section[:modifiers].inspect}\n#{section[:text]}\n"
      end

      str
    end
  end
end