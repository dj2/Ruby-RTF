module RubyRTF
  # Represents the entire RTF document
  class Document
    # @return [Hash] The font table
    attr_reader :font_table

    # @return [Integer] The default font number for the document
    attr_accessor :default_font

    # @return [String] The characgter set for the document (:ansi, :pc, :pca, :mac)
    attr_accessor :character_set

    # Creates a new document
    #
    # @return [RubyRTF::Document] The new document
    def initialize
      @font_table = []
    end

    # Convert RubyRTF::Document to a string
    #
    # @return [String] String version of the document
    def to_s
      str = "RTF Document:\n" +
            "  Font Table:\n"

      font_table.keys.sort.each do |key|
        str << "    #{key}: #{font_table[key]}\n"
      end

      str
    end
  end
end