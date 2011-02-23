module RubyRTF
  class Table
    attr_reader :rows

    def initialize
      @rows = [[]]
    end

    def add_row
      return if @rows.last.empty?
      @rows << []
    end
  end
end