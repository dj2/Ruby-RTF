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

    # @return [Array] The current formatting block to use as the basis for new sections
    attr_reader :formatting_stack

    # Keys that aren't inherited
    BLACKLISTED = [:paragraph, :newline, :tab, :lquote, :rquote, :ldblquote, :rdblquote]

    # Creates a new document
    #
    # @return [RubyRTF::Document] The new document
    def initialize
      @font_table = []
      @colour_table = []
      @character_set = :ansi
      @default_font = 0

      default_mods = {}
      @formatting_stack = [default_mods]
      @sections = [{:text => '', :modifiers => default_mods}]
    end

    # Add a new section to the document
    # @note If there is no text added to the current section this does nothing
    #
    # @return [Nil]
    def add_section!
      return if current_section[:text].empty?
      force_section!
    end

    # Adds a new section to the document regardless if the current section is empty
    #
    # @return [Nil]
    def force_section!
      mods = {}
      if current_section
        formatting_stack.last.each_pair do |k, v|
          next if BLACKLISTED.include?(k)
          mods[k] = v
        end
      end
      formatting_stack.push(mods)

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

    # Pop the current top element off the formatting stack.
    # @note This will not allow you to remove the defualt formatting parameters
    #
    # @return [Nil]
    def pop_formatting!
      formatting_stack.pop if @formatting_stack.length > 1
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