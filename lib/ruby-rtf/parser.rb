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
          current_pos = handle_control(name, val, src, current_pos, doc)

        when '{' then
          doc.add_section!
          group_level += 1

        when '}' then
          doc.pop_formatting!
          doc.add_section!
          group_level -= 1

        when *["\r", "\n"] then ;
        else doc.current_section[:text] << char
        end
      end

      raise RubyRTF::InvalidDocument.new("Unbalanced {}s") unless group_level == 0

      doc.remove_current_section! if doc.current_section[:text].empty?
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

      # handle hex special
      if src[current_pos] == "'"
        val = src[(current_pos + 1), 2].hex.chr
        current_pos += 3
        return [:hex, val, current_pos]
      end

      while (true)
        break if current_pos >= max_len
        break if [' ', '\\', '{', '}', "\r", "\n", ';'].include?(src[current_pos])

        current_pos += 1
      end
      contents = src[start, current_pos - start]

      m = contents.match(/([\*a-z]+)(\-?\d+)?\*?/)
      ctrl = m[1].to_sym
      val = m[2].to_i unless $2.nil?

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
      when :rtf then ;
      when :deff then doc.default_font = val
      when *[:ansi, :mac, :pc, :pca] then doc.character_set = name
      when :fonttbl then current_pos = parse_font_table(src, current_pos, doc)
      when :colortbl then current_pos = parse_colour_table(src, current_pos, doc)
      when :stylesheet then current_pos = parse_stylesheet(src, current_pos, doc)
      when :info  then current_pos = parse_info(src, current_pos, doc)
      when :* then current_pos = parse_skip(src, current_pos, doc)

      when :f then
        doc.add_section!
        doc.current_section[:modifiers][:font] = doc.font_table[val]
      # RTF font sizes are in half-points. divide by 2 to get points
      when :fs then
        doc.add_section!
        doc.current_section[:modifiers][:font_size] = (val.to_f / 2.0)

      when :b then
        doc.add_section!
        doc.current_section[:modifiers][:bold] = true

      when :i then
        doc.add_section!
        doc.current_section[:modifiers][:italic] = true

      when :ul then
        doc.add_section!
        doc.current_section[:modifiers][:underline] = true

      else puts "Unknown control #{name} with #{val} at #{current_pos}"
      end
      current_pos
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

      font = nil
      in_extra = nil

      while (true)
        case(src[current_pos])
        when '{' then
          font = RubyRTF::Font.new if group == 1
          in_extra = nil

          group += 1

        when '}' then
          group -= 1

          if group == 1
            font.cleanup_names
            doc.font_table[font.number] = font
          end

          in_extra = nil

          break if group == 0

        when '\\' then
          ctrl, val, current_pos = parse_control(src, current_pos + 1)

          case(ctrl)
          when :f then font.number = val
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
        when *["\r", "\n"] then ;
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

    # Parses the colour table group
    #
    # @param src [String] The source document
    # @param current_pos [Integer] The starting position
    # @param doc [RubyRTF::Document] The document
    # @return [Integer] The new current position
    #
    # @api private
    def self.parse_colour_table(src, current_pos, doc)
      if src[current_pos] == ';'
        colour = RubyRTF::Colour.new
        colour.use_default = true

        doc.colour_table << colour

        current_pos += 1
      end

      colour = RubyRTF::Colour.new

      while (true)
        case(src[current_pos])
        when '\\' then
          ctrl, val, current_pos = parse_control(src, current_pos + 1)

          case(ctrl)
          when :red then colour.red = val
          when :green then colour.green = val
          when :blue then colour.blue = val
          when :ctint then colour.tint = val
          when :cshade then colour.shade = val
          when *[:cmaindarkone, :cmainlightone, :cmaindarktwo, :cmainlighttwo, :caccentone,
                 :caccenttwo, :caccentthree, :caccentfour, :caccentfive, :caccentsix,
                 :chyperlink, :cfollowedhyperlink, :cbackgroundone, :ctextone,
                 :cbackgroundtwo, :ctexttwo] then
            colour.theme = ctrl.to_s[1..-1].to_sym
          end

        when *["\r", "\n"] then current_pos += 1
        when ';' then
          doc.colour_table << colour

          colour = RubyRTF::Colour.new
          current_pos += 1

        when '}' then break
        end
      end

      current_pos
    end

    # Parses the stylesheet group
    #
    # @param src [String] The source document
    # @param current_pos [Integer] The starting position
    # @param doc [RubyRTF::Document] The document
    # @return [Integer] The new current position
    #
    # @api private
    def self.parse_stylesheet(src, current_pos, doc)
      group = 1
      while (true)
        case(src[current_pos])
        when '{' then group += 1
        when '}' then
          group -= 1
          break if group == 0
        end
        current_pos += 1
      end

      current_pos
    end

    # Parses the info group
    #
    # @param src [String] The source document
    # @param current_pos [Integer] The starting position
    # @param doc [RubyRTF::Document] The document
    # @return [Integer] The new current position
    #
    # @api private
    def self.parse_info(src, current_pos, doc)
      group = 1
      while (true)
        case(src[current_pos])
        when '{' then group += 1
        when '}' then
          group -= 1
          break if group == 0
        end
        current_pos += 1
      end

      current_pos
    end

    # Parses a comment group
    #
    # @param src [String] The source document
    # @param current_pos [Integer] The starting position
    # @param doc [RubyRTF::Document] The document
    # @return [Integer] The new current position
    #
    # @api private
    def self.parse_skip(src, current_pos, doc)
      group = 1
      while (true)
        case(src[current_pos])
        when '{' then group += 1
        when '}' then
          group -= 1
          break if group == 0
        end
        current_pos += 1
      end

      current_pos
    end
  end
end
