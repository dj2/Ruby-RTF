module RubyRTF
  # Handles the parsing of RTF content into an RTF::Document
  class Parser
    # Parses a given string into an RubyRTF::Document
    #
    # @param src [String] The document to parse
    # @return [RTF::Document] The RTF document representing the provided @doc
    # @raise [RTF::InvalidDocument] Raised if the document is not valid RTF
    def self.parse(src)
      raise RubyRTF::InvalidDocument.new("Opening \\rtf1 missing") unless src =~ /\{\\rtf1/

      doc = RubyRTF::Document.new

      current_pos = 0
      len = src.length

      group_level = 0
      while (current_pos < len)
        char = src[current_pos]
        current_pos += 1

        case(char)
        when '\\' then
          name, val, current_pos = parse_control(src, current_pos)
          handle_control(name, val, src, current_pos, doc)

        when '{' then group_level += 1
        when '}' then group_level -= 1
        end
      end

      raise RubyRTF::InvalidDocument.new("Unbalanced {}s") unless group_level == 0
      doc
    end

    # Parses a control switch
    #
    # @param src [String] The fragment to parse
    # @param current_pos [Integer] The position in string the control starts at (after the \)
    # @return [name, val, current_pos] The name, optional control value and the new current position
    #
    # @api private
    def self.parse_control(src, current_pos = 0)
      ctrl = ''
      val = nil

      max_len = src.length
      start = current_pos

      current_pos += 1
      while (true)
        break if current_pos >= max_len
        break if [' ', '\\', '{', '}', "\r", "\n"].include?(src[current_pos])

        current_pos += 1
      end
      contents = src[start, current_pos - start]

      # handle hex codes a little different
      if contents =~ /^'/
        ctrl = :hex
        val = contents[1..-1].hex.chr
      else
        m = contents.match(/(['a-z]+)(\-?\d+)?\*?/)
        ctrl = m[1].to_sym
        val = m[2].to_i unless $2.nil?
      end

      # we advance past the optional space if present
      current_pos += 1 if src[current_pos] == ' '

      [ctrl, val, current_pos]
    end

    # Handle a given control
    #
    # @param name [Symbol] The control name
    # @param val [Integer|nil] The controls value, or nil if non associated
    # @param src [String] The source document
    # @param current_pos [Integer] The current document position
    # @param doc [RubyRTF::Document] The document
    # @return [Integer] The new current position
    #
    # @api private
    def self.handle_control(name, val, src, current_pos, doc)
      case(name)
      when :fonttbl then parse_font_table(src, current_pos, doc)
      end
    end

    # Parses the font table group
    #
    # @param src [String] The source document
    # @param current_pos [Integer] The starting position
    # @param doc [RubyRTF::Document] The document
    # @return [Integer] The new current position
    #
    # @api private
    def self.parse_font_table(src, current_pos, doc)
      group = 1

      font_num = nil
      font = nil
      name = nil

      while (group != 0)
        case(src[current_pos])
        when '{' then
          font = RubyRTF::Font.new
          name = ''
          group += 1
        when '}' then
          font.name = name.gsub(/;$/, '')
          doc.font_table[font_num] = font
          group -= 1
        when '\\' then
          ctrl, val, current_pos = parse_control(src, current_pos)

          if ctrl == :f
            font_num = val.to_s
          else
            font.family_command = ctrl.to_s[1..-1].to_sym
          end

          # need to next as parse_control will leave current_pos at the
          # next character already so current_pos += 1 below would move us too far
          next
        else
          name << src[current_pos]
        end
        current_pos += 1
      end

      current_pos - 1
    end
  end
end
