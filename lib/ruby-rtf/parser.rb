module RubyRTF
  # Handles the parsing of RTF content into an RubyRTF::Document
  class Parser
    # @return [Array] The current formatting block to use as the basis for new sections
    attr_reader :formatting_stack

    def initialize
      default_mods = {}
      @doc = RubyRTF::Document.new(default_mods)
      @formatting_stack = [default_mods]
    end

    # Parses a given string into an RubyRTF::Document
    #
    # @param src [String] The document to parse
    # @return [RubyRTF::Document] The RTF document representing the provided @doc
    # @raise [RubyRTF::InvalidDocument] Raised if the document is not valid RTF
    def parse(src)
      raise RubyRTF::InvalidDocument.new("Opening \\rtf1 missing") unless src =~ /\{\\rtf1/

      current_pos = 0
      len = src.length

      group_level = 0
      while (current_pos < len)
        char = src[current_pos]
        current_pos += 1

        case(char)
        when '\\' then
          name, val, current_pos = parse_control(src, current_pos)
          current_pos = handle_control(name, val, src, current_pos)

        when '{' then
          add_section!
          group_level += 1

        when '}' then
          pop_formatting!
          add_section!
          group_level -= 1

        when *["\r", "\n"] then ;
        else @doc.current_section[:text] << char
        end
      end

      raise RubyRTF::InvalidDocument.new("Unbalanced {}s") unless group_level == 0

      @doc.remove_current_section! if @doc.current_section[:text].empty?
      @doc
    end

    # Parses a control switch
    #
    # @param src [String] The fragment to parse
    # @param current_pos [Integer] The position in string the control starts at (after the \)
    # @return [String, String|Integer, Integer] The name, optional control value and the new current position
    #
    # @api private
    def parse_control(src, current_pos = 0)
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
    # @return [Integer] The new current position
    #
    # @api private
    def handle_control(name, val, src, current_pos)
      case(name)
      when :rtf then ;
      when :deff then @doc.default_font = val
      when *[:ansi, :mac, :pc, :pca] then @doc.character_set = name
      when :fonttbl then current_pos = parse_font_table(src, current_pos)
      when :colortbl then current_pos = parse_colour_table(src, current_pos)
      when :stylesheet then current_pos = parse_stylesheet(src, current_pos)
      when :info  then current_pos = parse_info(src, current_pos)
      when :* then current_pos = parse_skip(src, current_pos)

      when :f then add_section!(:font => @doc.font_table[val])

      # RTF font sizes are in half-points. divide by 2 to get points
      when :fs then add_section!(:font_size => (val.to_f / 2.0))
      when :b then add_section!(:bold => true)
      when :i then add_section!(:italic => true)
      when :ul then add_section!(:underline => true)
      when :super then add_section!(:superscript => true)
      when :sub then add_section!(:subscript => true)
      when :strike then add_section!(:strikethrough => true)
      when :scaps then add_section!(:smallcaps => true)
      when :cf then add_section!(:foreground_colour => @doc.colour_table[val])
      when :cb then add_section!(:background_colour => @doc.colour_table[val])
      when :hex then @doc.current_section[:text] << val
      when :u then
        char = if val > 0
          '\u' + val
        else
          '\u' + (val + 65_536).to_s
        end
        @doc.current_section[:text] << char

      # force a new section so we can mark this as a [rl]quote section
      # but stick the ' in the text so it can be displayed easily
      when *[:rquote, :lquote] then
        force_section!(name => true)
        @doc.current_section[:text] << "'"
        force_section!

      # force a new section so we can mark this as a [rl]dbquote section
      # but stick the " in the text so it can be displayed easily
      when *[:rdblquote, :ldblquote] then
        force_section!(name => true)
        @doc.current_section[:text] << '"'
        force_section!

      when :'{' then @doc.current_section[:text] << "{"
      when :'}' then @doc.current_section[:text] << "}"
      when :'\\' then @doc.current_section[:text] << '\\'

      when :tab then
        force_section!(:tab => true)
        @doc.current_section[:text] << "\t"
        pop_formatting!

        force_section!
        pop_formatting!

      when :emdash then
        force_section!(:emdash => true)
        @doc.current_section[:text] << "--"
        pop_formatting!

        force_section!
        pop_formatting!

      when :endash then
        force_section!(:endash => true)
        @doc.current_section[:text] << "-"
        pop_formatting!

        force_section!
        pop_formatting!

      when *[:line, :'\n'] then
        force_section!(:newline => true)
        @doc.current_section[:text] << "\n"
        pop_formatting!

        force_section!
        pop_formatting!

      when :'\r' then ;

      when :par then
        # force a fake section for the paragraph and then remove it
        # from the formatting stack. We then add a new section after the paragraph
        # which we also remove from the stack. Any new switches will for an
        # add_group which will add a new section
        force_section!(:paragraph => true)
        pop_formatting!

        force_section!
        pop_formatting!

      when *[:pard, :plain] then @doc.reset_current_section!

      when :trowd then ;
      when :cell then ;
      when :row then ;
      when :intbl then ;

      else STDERR.puts "Unknown control #{name} with #{val} at #{current_pos}"
      end
      current_pos
    end

    # Parses the font table group
    #
    # @param src [String] The source document
    # @param current_pos [Integer] The starting position
    # @return [Integer] The new current position
    #
    # @api private
    def parse_font_table(src, current_pos)
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
            @doc.font_table[font.number] = font
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
    # @return [Integer] The new current position
    #
    # @api private
    def parse_colour_table(src, current_pos)
      if src[current_pos] == ';'
        colour = RubyRTF::Colour.new
        colour.use_default = true

        @doc.colour_table << colour

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
          @doc.colour_table << colour

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
    # @return [Integer] The new current position
    #
    # @api private
    def parse_stylesheet(src, current_pos)
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
    # @return [Integer] The new current position
    #
    # @api private
    def parse_info(src, current_pos)
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
    # @return [Integer] The new current position
    #
    # @api private
    def parse_skip(src, current_pos)
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

    # Keys that aren't inherited
    BLACKLISTED = [:paragraph, :newline, :tab, :lquote, :rquote, :ldblquote, :rdblquote]

    def calc_current_modifiers(mods = {})
      if @doc.current_section
        formatting_stack.last.each_pair do |k, v|
          next if BLACKLISTED.include?(k)
          mods[k] = v
        end
      end
      formatting_stack.push(mods)
      mods
    end

    def add_section!(mods = {})
      if @doc.current_section[:text].empty?
        @doc.current_section[:modifiers].merge!(mods)
      else
        force_section!(mods)
      end
    end

    def force_section!(mods = {})
      @doc.add_section!(calc_current_modifiers.merge(mods))
    end

    # Pop the current top element off the formatting stack.
    # @note This will not allow you to remove the defualt formatting parameters
    #
    # @return [Nil]
    def pop_formatting!
      formatting_stack.pop if formatting_stack.length > 1
    end
  end
end
