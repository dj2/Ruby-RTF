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
    def initialize(default_mods)
      @font_table = []
      @colour_table = []
      @character_set = :ansi
      @default_font = 0

      @sections = [{:text => '', :modifiers => default_mods}]
    end

    # Adds a new section to the document regardless if the current section is empty
    #
    # @return [Nil]
    def add_section!(mods = {})
      @sections << {:text => '', :modifiers => mods}
    end

    # Resets the current section to default formating
    #
    # @return [Nil]
    def reset_current_section!
      current_section[:modifiers].clear
    end

    # Reset the current section to default settings
    #
    # @return [Nil]
    def reset_section!
      current_section[:modifiers] = {}
    end

    # Removes the last section
    #
    # @return [Nil]
    def remove_current_section!
      sections.pop
    end

    # Retrieve the current section for the document
    #
    # @return [Hash] The document section data
    def current_section
      sections.last
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