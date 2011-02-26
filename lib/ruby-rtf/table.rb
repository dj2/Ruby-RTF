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
      attr_accessor :table, :end_positions, :cells

      def initialize(table)
        @table = table
        @end_positions = []

        @cells = [RubyRTF::Table::Row::Cell.new(self, 0)]
      end

      def current_cell
        @cells.last
      end

      def add_cell
        return @cells.last if @cells.last.sections.empty?

        @cells << RubyRTF::Table::Row::Cell.new(self, @cells.length)
        @cells.last
      end

      class Cell
        attr_accessor :sections, :row, :idx

        def initialize(row, idx)
          @row = row
          @idx = idx
          @sections = []
        end

        def <<(obj)
          @sections << obj
        end

        def table
          row.table
        end

        def width
          gap = row.table.half_gap
          left_margin = row.table.left_margin

          end_pos = row.end_positions[idx]
          prev_pos = idx == 0 ? 0 : row.end_positions[idx - 1]

          end_pos - prev_pos - (2 * gap) - left_margin
        end
      end
    end
  end
end
