module RubyRTF
  # Handles the parsing of RTF content into an RubyRTF::Document
  class Parser
    # Parses a given string into an RubyRTF::Document
    #
    # @param src [String] The document to parse
    # @return [RubyRTF::Document] The RTF document representing the provided @doc
    # @raise [RubyRTF::InvalidDocument] Raised if the document is not valid RTF
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
    # @return [String, String|Integer, Integer] The name, optional control value and the new current position
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
        m = contents.match(/([\*a-z]+)(\-?\d+)?\*?/)
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
      when :deff then doc.default_font = val.to_s

      when *[:ansi, :mac, :pc, :pca] then doc.character_set = name
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

      in_extra = nil

      while (group != 0)
        case(src[current_pos])
        when '{' then
          font = RubyRTF::Font.new if group == 1
          in_extra = nil

          group += 1

        when '}' then
          group -= 1

          if group == 1
            font.cleanup_names
            doc.font_table[font_num] = font
          end

          in_extra = nil

          break if group == 0

        when '\\' then
          ctrl, val, current_pos = parse_control(src, current_pos)

          case(ctrl)
          when :f then font_num = val
          when :fprq then font.pitch = val
          when :fcharset then font.character_set = val
          when *[:flomajor, :fhimajor, :fdbmajor, :fbimajor,
                 :flominor, :fhiminor, :fdbminor, :fbiminor] then
            font.theme = ctrl.to_s[1..-1].to_sym

          when *[:falt, :fname, :panose] then in_extra = ctrl
          else
            cmd = ctrl.to_s[1..-1].to_sym
            if RubyRTF::Font::FAMILIES.include?(cmd)
              font.family_command = cmd
            end
          end

          # need to next as parse_control will leave current_pos at the
          # next character already so current_pos += 1 below would move us too far
          next
        else
          case(in_extra)
          when :falt then font.alternate_name << src[current_pos]
          when :panose then font.panose << src[current_pos]
          when :fname then font.non_tagged_name << src[current_pos]
          when nil then font.name << src[current_pos]
          end
        end
        current_pos += 1
      end

      current_pos
    end
  end
end
