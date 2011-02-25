module RubyRTF
  class Table
    attr_accessor :rows, :half_gap

    def initialize
      @rows = [RubyRTF::Table::Row.new(self)]
    end

    def current_row
      @rows.last
    end

    class Row
      attr_accessor :sections, :table, :cells

      def initialize(table)
        @table = table
        @cells = []

        @sections = []
      end
    end
  end
end