module RubyRTF
  class Table
    attr_accessor :rows, :half_gap, :left_margin

    def initialize
      @left_margin = 0
      @half_gap = 0

      @rows = []
      add_row
    end

    def current_row
      @rows.last
    end

    def add_row
      @rows << RubyRTF::Table::Row.new(self)
      @rows.last
    end

    class Row
      attr_accessor :table, :widths, :cells

      def initialize(table)
        @table = table
        @widths = []
        @cells = []
        add_cell
      end

      def current_cell
        @cells.last
      end

      def add_cell
        return @cells.last if (@cells.length > 0) && @cells.last.sections.empty?

        @cells << RubyRTF::Table::Row::Cell.new(self)
        @cells.last
      end

      class Cell
        attr_accessor :sections, :row

        def initialize(row)
          @row = row
          @sections = []
        end
      end
    end
  end
end