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
    def initialize
      @font_table = []
      @colour_table = []
      @character_set = :ansi
      @default_font = 0

      @sections = []
    end

    def <<(obj)
      @sections << obj
    end
  end
end