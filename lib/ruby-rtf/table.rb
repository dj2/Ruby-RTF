module RubyRTF
  class Table
    attr_accessor :rows, :half_gap

    def initialize
      @rows = []
      add_row
    end

    def current_row
      @rows.last
    end

    def add_row
      @rows << RubyRTF::Table::Row.new(self)
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