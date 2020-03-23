# encoding: utf-8

require 'spec_helper'

describe RubyRTF::Parser do
  let(:parser) { RubyRTF::Parser.new }
  let(:doc) { parser.doc }

  context 'with input containing invalid control directives' do
    let(:parser) { RubyRTF::Parser.new(unknown_control_warning_enabled: unknown_control_warning_enabled) }
    let(:doc) { '{\rtf1\ansi\xxxxx0}' }

    context 'with unknown_control_warning_enabled = false' do
      let(:unknown_control_warning_enabled) { false }

      it 'does not write anything to stderr' do
        expect { parser.parse(doc) }.not_to output.to_stderr
      end
    end
    context 'with unknown_control_warning_enabled = true' do
      let(:unknown_control_warning_enabled) { true }

      it 'writes message to stderr' do
        expect { parser.parse(doc) }.to output("Unknown control :xxxxx with 0 at 18\n").to_stderr
      end
    end
  end

  it 'parses hello world' do
    src = '{\rtf1\ansi\deff0 {\fonttbl {\f0 Times New Roman;}}\f0 \fs60 Hello, World!}'
    lambda { parser.parse(src) }.should_not raise_error
  end

  it 'returns a RTF::Document' do
    src = '{\rtf1\ansi\deff0 {\fonttbl {\f0 Times New Roman;}}\f0 \fs60 Hello, World!}'
    d = parser.parse(src)
    d.is_a?(RubyRTF::Document).should  == true
  end

  it 'parses a default font (\deffN)' do
    src = '{\rtf1\ansi\deff10 {\fonttbl {\f10 Times New Roman;}}\f0 \fs60 Hello, World!}'
    d = parser.parse(src)
    d.default_font.should == 10
  end

  context 'invalid document' do
    it 'raises exception if \rtf is missing' do
      src = '{\ansi\deff0 {\fonttbl {\f0 Times New Roman;}}\f0 \fs60 Hello, World!}'
      lambda { parser.parse(src) }.should raise_error(RubyRTF::InvalidDocument)
    end

    it 'raises exception if the document does not start with \rtf' do
      src = '{\ansi\deff0\rtf1 {\fonttbl {\f0 Times New Roman;}}\f0 \fs60 Hello, World!}'
      lambda { parser.parse(src) }.should raise_error(RubyRTF::InvalidDocument)
    end

    it 'raises exception if the {}s are unbalanced' do
      src = '{\rtf1\ansi\deff0 {\fonttbl {\f0 Times New Roman;}\f0 \fs60 Hello, World!}'
      lambda { parser.parse(src) }.should raise_error(RubyRTF::InvalidDocument)
    end
  end

  context '#parse' do
    it 'parses text into the current section' do
      src = '{\rtf1\ansi\deff10 {\fonttbl {\f10 Times New Roman;}}\f0 \fs60 Hello, World!}'
      d = parser.parse(src)
      d.sections.first[:text].should == 'Hello, World!'
    end

    it 'adds a new section on {' do
      src = '{\rtf1 \fs60 Hello {\fs30 World}}'
      d = parser.parse(src)
      d.sections.first[:modifiers][:font_size].should == 30
      d.sections.first[:text].should == 'Hello '

      d.sections.last[:modifiers][:font_size].should == 15
      d.sections.last[:text].should == 'World'
    end

    it 'adds a new section on }' do
      src = '{\rtf1 \fs60 Hello {\fs30 World}\fs12 Goodbye, cruel world.}'

      section = parser.parse(src).sections
      section[0][:modifiers][:font_size].should == 30
      section[0][:text].should == 'Hello '

      section[1][:modifiers][:font_size].should == 15
      section[1][:text].should == 'World'

      section[2][:modifiers][:font_size].should == 6
      section[2][:text].should == 'Goodbye, cruel world.'
    end

    it 'inherits properly over {} groups' do
      src = '{\rtf1 \b\fs60 Hello {\i\fs30 World}\ul Goodbye, cruel world.}'

      section = parser.parse(src).sections
      section[0][:modifiers][:font_size].should == 30
      section[0][:modifiers][:bold].should == true
      section[0][:modifiers].has_key?(:italic).should == false
      section[0][:modifiers].has_key?(:underline).should == false
      section[0][:text].should == 'Hello '

      section[1][:modifiers][:font_size].should == 15
      section[1][:modifiers][:italic].should == true
      section[1][:modifiers][:bold].should == true
      section[1][:modifiers].has_key?(:underline).should == false
      section[1][:text].should == 'World'

      section[2][:modifiers][:font_size].should == 30
      section[2][:modifiers][:bold].should == true
      section[2][:modifiers][:underline].should == true
      section[2][:modifiers].has_key?(:italic).should == false
      section[2][:text].should == 'Goodbye, cruel world.'
    end

    context 'parses pictures' do
      let(:src_bitmap) do
        src = '{\rtf1 {\pict\wbitmap\picw7064\pich5292\picwgoal4005\pichgoal3000\picscalex111\picscaley109
ffd8ffe000104a4649460001010100b400b40000ffe1158a687474703a2f2f6e732e61646f62652e636f6d2f7861702f3}}'
      end
      let(:src_jpeg) do
        src = '{\rtf1 {\pict\jpegblip\picw7064\pich5292\picwgoal4005\pichgoal3000\picscalex111\picscaley109
ffd8ffe000104a4649460001010100b400b40000ffe1158a687474703a2f2f6e732e61646f62652e636f6d2f7861702f3}}'
      end

      it 'should parse jpeg' do
        section = parser.parse(src_jpeg).sections
        section[0][:modifiers][:picture].should == true
        section[0][:modifiers][:picture_format].should == 'jpeg'
      end

      it 'should parse bmp' do
        section = parser.parse(src_bitmap).sections
        section[0][:modifiers][:picture].should == true
        section[0][:modifiers][:picture_format].should == 'bmp'
        section = parser.parse(src_bitmap).sections
        section[0][:modifiers][:picture].should == true
        section[0][:modifiers][:picture_format].should == 'bmp'
      end

      it 'should parse width' do
        section = parser.parse(src_bitmap).sections
        section[0][:modifiers][:picture_width].should == 7064 / 20.0
      end

      it 'should parse height' do
        section = parser.parse(src_bitmap).sections
        section[0][:modifiers][:picture_height].should == 5292 / 20.0
      end

      it 'should parse scale' do
        section = parser.parse(src_bitmap).sections
        section[0][:modifiers][:picture_scale_x].should == 111
        section[0][:modifiers][:picture_scale_y].should == 109
      end

      it 'should parse picture data' do
        section = parser.parse(src_bitmap).sections
        section[0][:text].should == 'ffd8ffe000104a4649460001010100b400b40000ffe1158a687474703a2f2f6e732e61646f62652e636f6d2f7861702f3'
      end
    end

    it 'clears ul with ul0' do
      src = '{\rtf1 \ul\b Hello\b0\ul0 World}'
      section = parser.parse(src).sections
      section[0][:modifiers][:bold].should == true
      section[0][:modifiers][:underline].should == true
      section[0][:text].should == 'Hello'

      section[1][:modifiers].has_key?(:bold).should == false
      section[1][:modifiers].has_key?(:underline).should == false
      section[1][:text].should == 'World'
    end
  end

  context '#parse_control' do
    it 'parses a normal control' do
      parser.parse_control("rtf")[0, 2].should == [:rtf, nil]
    end

    it 'parses a control with a value' do
      parser.parse_control("f2")[0, 2].should == [:f, 2]
    end

    context 'unicode' do
      %w(u21487* u21487).each do |code|
        it "parses #{code}" do
          parser.parse_control(code)[0, 2].should == [:u, 21487]
        end
      end

      %w(u-21487* u-21487).each do |code|
        it "parses #{code}" do
          parser.parse_control(code)[0, 2].should == [:u, -21487]
        end
      end
    end

    it 'parses a hex control' do
      parser.parse_control("'7e")[0, 2].should == [:hex, '~']
    end

    it 'parses a hex control with a string after it' do
      ctrl, val, current_pos = parser.parse_control("'7e25")
      ctrl.should == :hex
      val.should == '~'
      current_pos.should == 3
    end

    context "encoding is windows-1252" do
      it 'parses a hex control' do
        parser.encoding = 'windows-1252'
        parser.parse_control("'93")[0, 2].should == [:hex, '“']
      end
    end

    [' ', '{', '}', '\\', "\r", "\n"].each do |stop|
      it "stops at a #{stop}" do
        parser.parse_control("rtf#{stop}test")[0, 2].should == [:rtf, nil]
      end
    end

    it 'handles a non-zero current position' do
      parser.parse_control('Test ansi test', 5)[0, 2].should == [:ansi, nil]
    end

    it 'advances the current positon' do
      parser.parse_control('Test ansi{test', 5).last.should == 9
    end

    it 'advances the current positon past the optional space' do
      parser.parse_control('Test ansi test', 5).last.should == 10
    end
  end

  context 'character set' do
    %w(ansi mac pc pca).each do |type|
      it "accepts #{type}" do
        src = "{\\rtf1\\#{type}\\deff0 {\\fonttbl {\\f0 Times New Roman;}}\\f0 \\fs60 Hello, World!}"
        doc = parser.parse(src)
        doc.character_set.should == type.to_sym
      end
    end
  end

  context 'font table' do
    it 'sets the font table into the document' do
      src = '{\rtf1{\fonttbl{\f0\froman Times;}{\f1\fnil Arial;}}}'
      doc = parser.parse(src)

      font = doc.font_table[0]
      font.family_command.should == :roman
      font.name.should == 'Times'
    end

    it 'parses an empty font table' do
      src = "{\\rtf1\\ansi\\ansicpg1252\\cocoartf1187\n{\\fonttbl}\n{\\colortbl;\\red255\\green255\\blue255;}\n}"
      doc = parser.parse(src)

      doc.font_table.should == []
    end

    context '#parse_font_table' do
      it 'parses a font table' do
        src = '{\f0\froman Times New Roman;}{\f1\fnil Arial;}}}'
        parser.parse_font_table(src, 0)
        tbl = doc.font_table

        tbl.length.should == 2
        tbl[0].family_command.should == :roman
        tbl[0].name.should == 'Times New Roman'

        tbl[1].family_command.should == :nil
        tbl[1].name.should == 'Arial'
      end

      it 'parses a font table without braces' do
        src = '\f0\froman\fcharset0 TimesNewRomanPSMT;}}'
        parser.parse_font_table(src, 0)
        tbl = doc.font_table
        tbl[0].name.should == 'TimesNewRomanPSMT'
      end

      it 'handles \r and \n in the font table' do
        src = "{\\f0\\froman Times New Roman;}\r{\\f1\\fnil Arial;}\n}}"
        parser.parse_font_table(src, 0)
        tbl = doc.font_table

        tbl.length.should == 2
        tbl[0].family_command.should == :roman
        tbl[0].name.should == 'Times New Roman'

        tbl[1].family_command.should == :nil
        tbl[1].name.should == 'Arial'
      end

      it 'the family command is optional' do
        src = '{\f0 Times New Roman;}}}'
        parser.parse_font_table(src, 0)
        tbl = doc.font_table
        tbl[0].family_command.should == :nil
        tbl[0].name.should == 'Times New Roman'
      end

      it 'does not require the numbering to be incremental' do
        src = '{\f77\froman Times New Roman;}{\f3\fnil Arial;}}}'
        parser.parse_font_table(src, 0)
        tbl = doc.font_table

        tbl[77].family_command.should == :roman
        tbl[77].name.should == 'Times New Roman'

        tbl[3].family_command.should == :nil
        tbl[3].name.should == 'Arial'
      end

      it 'accepts the \falt command' do
        src = '{\f0\froman Times New Roman{\*\falt Courier New};}}'
        parser.parse_font_table(src, 0)
        tbl = doc.font_table
        tbl[0].name.should == 'Times New Roman'
        tbl[0].alternate_name.should == 'Courier New'
      end

      it 'sets current pos to the closing }' do
        src = '{\f0\froman Times New Roman{\*\falt Courier New};}}'
        parser.parse_font_table(src, 0).should == (src.length - 1)
      end

      it 'accepts the panose command' do
        src = '{\f0\froman\fcharset0\fprq2{\*\panose 02020603050405020304}Times New Roman{\*\falt Courier New};}}'
        parser.parse_font_table(src, 0)
        tbl = doc.font_table
        tbl[0].panose.should == '02020603050405020304'
        tbl[0].name.should == 'Times New Roman'
        tbl[0].alternate_name.should == 'Courier New'
      end

      %w(flomajor fhimajor fdbmajor fbimajor flominor fhiminor fdbminor fbiminor).each do |type|
        it "handles theme font type: #{type}" do
          src = "{\\f0\\#{type} Times New Roman;}}"
          parser.parse_font_table(src, 0)
          tbl = doc.font_table
          tbl[0].name.should == 'Times New Roman'
          tbl[0].theme.should == type[1..-1].to_sym
        end
      end

      [[0, :default], [1, :fixed], [2, :variable]].each do |pitch|
        it 'parses pitch information' do
          src = "{\\f0\\fprq#{pitch.first} Times New Roman;}}"
          parser.parse_font_table(src, 0)
          tbl = doc.font_table
          tbl[0].name.should == 'Times New Roman'
          tbl[0].pitch.should == pitch.last
        end
      end

      it 'parses the non-tagged font name' do
        src = '{\f0{\*\fname Arial;}Times New Roman;}}'
        parser.parse_font_table(src, 0)
        tbl = doc.font_table
        tbl[0].name.should == 'Times New Roman'
        tbl[0].non_tagged_name.should == 'Arial'
      end

      it 'parses the charset' do
        src = '{\f0\fcharset87 Times New Roman;}}'
        parser.parse_font_table(src, 0)
        tbl = doc.font_table
        tbl[0].name.should == 'Times New Roman'
        tbl[0].character_set.should == 87
      end
    end
  end

  context 'colour table' do
    it 'sets the colour table into the document' do
      src = '{\rtf1{\colortbl\red0\green0\blue0;\red127\green2\blue255;}}'
      doc = parser.parse(src)

      clr = doc.colour_table[0]
      clr.red.should == 0
      clr.green.should == 0
      clr.blue.should == 0

      clr = doc.colour_table[1]
      clr.red.should == 127
      clr.green.should == 2
      clr.blue.should == 255
    end

    it 'ignores single space between colour sections' do
      src = '{\rtf1{\colortbl\red0\green0\blue0; \red127\green2\blue255;}}'
      doc = parser.parse(src)

      clr = doc.colour_table[0]
      clr.red.should == 0
      clr.green.should == 0
      clr.blue.should == 0

      clr = doc.colour_table[1]
      clr.red.should == 127
      clr.green.should == 2
      clr.blue.should == 255
    end

    it 'ignores double space between colour sections' do
      src = '{\rtf1{\colortbl\red0\green0\blue0;  \red127\green2\blue255;}}'
      doc = parser.parse(src)

      clr = doc.colour_table[0]
      clr.red.should == 0
      clr.green.should == 0
      clr.blue.should == 0

      clr = doc.colour_table[1]
      clr.red.should == 127
      clr.green.should == 2
      clr.blue.should == 255
    end

    it 'sets the first colour if missing' do
      src = '{\rtf1{\colortbl;\red255\green0\blue0;\red0\green0\blue255;}}'
      doc = parser.parse(src)

      clr = doc.colour_table[0]
      clr.use_default?.should == true

      clr = doc.colour_table[1]
      clr.red.should == 255
      clr.green.should == 0
      clr.blue.should == 0
    end

    context '#parse_colour_table' do
      it 'parses \red \green \blue' do
        src = '\red2\green55\blue23;}'
        parser.parse_colour_table(src, 0)
        tbl = doc.colour_table
        tbl[0].red.should == 2
        tbl[0].green.should == 55
        tbl[0].blue.should == 23
      end

      it 'handles ctintN' do
        src = '\ctint22\red2\green55\blue23;}'
        parser.parse_colour_table(src, 0)
        tbl = doc.colour_table
        tbl[0].tint.should == 22
      end

      it 'handles cshadeN' do
        src = '\cshade11\red2\green55\blue23;}'
        parser.parse_colour_table(src, 0)
        tbl = doc.colour_table
        tbl[0].shade.should == 11
      end

      %w(cmaindarkone cmainlightone cmaindarktwo cmainlighttwo caccentone
         caccenttwo caccentthree caccentfour caccentfive caccentsix
         chyperlink cfollowedhyperlink cbackgroundone ctextone
         cbackgroundtwo ctexttwo).each do |theme|
        it "it allows theme item #{theme}" do
          src = "\\#{theme}\\red11\\green22\\blue33;}"
          parser.parse_colour_table(src, 0)
          tbl = doc.colour_table
          tbl[0].theme.should == theme[1..-1].to_sym
        end
      end

      it 'handles \r and \n' do
        src = "\\cshade11\\red2\\green55\r\n\\blue23;}"
        parser.parse_colour_table(src, 0)
        tbl = doc.colour_table
        tbl[0].shade.should == 11
        tbl[0].red.should == 2
        tbl[0].green.should == 55
        tbl[0].blue.should == 23
      end
    end
  end

  context 'stylesheet' do
    it 'parses a stylesheet'
  end

  context 'document info' do
    it 'parse the doocument info'
  end

  context '#handle_control' do
     it 'sets the font' do
      font = RubyRTF::Font.new('Times New Roman')
      doc.font_table[0] = font

      parser.handle_control(:f, 0, nil, 0)
      parser.current_section[:modifiers][:font].should == font
    end

    it 'sets the font size' do
      parser.handle_control(:fs, 61, nil, 0)
      parser.current_section[:modifiers][:font_size].should == 30.5
    end

    it 'sets bold' do
      parser.handle_control(:b, nil, nil, 0)
      parser.current_section[:modifiers][:bold].should == true
    end

    it 'sets underline' do
      parser.handle_control(:ul, nil, nil, 0)
      parser.current_section[:modifiers][:underline].should == true
    end

    it 'sets italic' do
      parser.handle_control(:i, nil, nil, 0)
      parser.current_section[:modifiers][:italic].should == true
    end

    %w(rquote lquote).each do |quote|
      it "sets a #{quote}" do
        parser.current_section[:text] = 'My code'
        parser.handle_control(quote.to_sym, nil, nil, 0)
        doc.sections.last[:text].should == "'"
        doc.sections.last[:modifiers][quote.to_sym].should == true
      end
    end

    %w(rdblquote ldblquote).each do |quote|
      it "sets a #{quote}" do
        parser.current_section[:text] = 'My code'
        parser.handle_control(quote.to_sym, nil, nil, 0)
        doc.sections.last[:text].should == '"'
        doc.sections.last[:modifiers][quote.to_sym].should == true
      end
    end

    it 'sets a hex character' do
      parser.current_section[:text] = 'My code'
      parser.handle_control(:hex, '~', nil, 0)
      parser.current_section[:text].should == 'My code~'
    end

    it 'sets a unicode character < 1000 (char 643)' do
      parser.current_section[:text] = 'My code'
      parser.handle_control(:u, 643, nil, 0)
      parser.current_section[:text].should == 'My codeك'
    end

    it 'sets a unicode character < 32768 (char 2603)' do
      parser.current_section[:text] = 'My code'
      parser.handle_control(:u, 2603, nil, 0)
      parser.current_section[:text].should == 'My code☃'
    end

    it 'sets a unicode character < 32768 (char 21340)' do
      parser.current_section[:text] = 'My code'
      parser.handle_control(:u, 21340, nil, 0)
      parser.current_section[:text].should == 'My code卜'
    end


    it 'sets a unicode character > 32767 (char 36,947)' do
      parser.current_section[:text] = 'My code'
      parser.handle_control(:u, -28589, nil, 0)
      parser.current_section[:text].should == 'My code道'
    end

    context "uc0 skips a byte in the next unicode char" do
      it "u8278" do
        parser.current_section[:text] = 'My code '
        parser.handle_control(:uc, 0, nil, 0)
        parser.handle_control(:u, 8278, nil, 0)
        parser.current_section[:text].should == 'My code x'
      end

      it "u8232 - does newline" do
        parser.current_section[:text] = "end."
        parser.handle_control(:uc, 0, nil, 0)
        parser.handle_control(:u, 8232, nil, 0)
        doc.sections.last[:modifiers][:newline].should == true
        doc.sections.last[:text].should == "\n"
      end
    end

    context 'new line' do
      ['line', "\n"].each do |type|
        it "sets from #{type}" do
          parser.current_section[:text] = "end."
          parser.handle_control(type.to_sym, nil, nil, 0)
          doc.sections.last[:modifiers][:newline].should == true
          doc.sections.last[:text].should == "\n"
        end
      end

      it 'ignores \r' do
        parser.current_section[:text] = "end."
        parser.handle_control(:"\r", nil, nil, 0)
        parser.current_section[:text].should == "end."
      end
    end

    it 'inserts a \tab' do
      parser.current_section[:text] = "end."
      parser.handle_control(:tab, nil, nil, 0)
      doc.sections.last[:modifiers][:tab].should == true
      doc.sections.last[:text].should == "\t"
    end

    it 'inserts a \super' do
      parser.current_section[:text] = "end."
      parser.handle_control(:super, nil, nil, 0)

      parser.current_section[:modifiers][:superscript].should == true
      parser.current_section[:text].should == ""
    end

    it 'inserts a \sub' do
      parser.current_section[:text] = "end."
      parser.handle_control(:sub, nil, nil, 0)

      parser.current_section[:modifiers][:subscript].should == true
      parser.current_section[:text].should == ""
    end

    it 'inserts a \strike' do
      parser.current_section[:text] = "end."
      parser.handle_control(:strike, nil, nil, 0)

      parser.current_section[:modifiers][:strikethrough].should == true
      parser.current_section[:text].should == ""
    end

    it 'inserts a \scaps' do
      parser.current_section[:text] = "end."
      parser.handle_control(:scaps, nil, nil, 0)

      parser.current_section[:modifiers][:smallcaps].should == true
      parser.current_section[:text].should == ""
    end

    it 'inserts an \emdash' do
      parser.current_section[:text] = "end."
      parser.handle_control(:emdash, nil, nil, 0)
      doc.sections.last[:modifiers][:emdash].should == true
      doc.sections.last[:text].should == "--"
    end

    it 'inserts an \endash' do
      parser.current_section[:text] = "end."
      parser.handle_control(:endash, nil, nil, 0)
      doc.sections.last[:modifiers][:endash].should == true
      doc.sections.last[:text].should == "-"
    end

    context 'escapes' do
      ['{', '}', '\\'].each do |escape|
        it "inserts an escaped #{escape}" do
          parser.current_section[:text] = "end."
          parser.handle_control(escape.to_sym, nil, nil, 0)
          parser.current_section[:text].should == "end.#{escape}"
        end
      end
    end

    it 'adds a new section for a par command' do
      parser.current_section[:text] = 'end.'
      parser.handle_control(:par, nil, nil, 0)
      parser.current_section[:text].should == ""
    end

    %w(pard plain).each do |type|
      it "resets the current sections information to default for #{type}" do
        parser.current_section[:modifiers][:bold] = true
        parser.current_section[:modifiers][:italic] = true
        parser.handle_control(type.to_sym, nil, nil, 0)

        parser.current_section[:modifiers].has_key?(:bold).should == false
        parser.current_section[:modifiers].has_key?(:italic).should == false
      end
    end

    context 'colour' do
      it 'sets the foreground colour' do
        doc.colour_table << RubyRTF::Colour.new(255, 0, 255)
        parser.handle_control(:cf, 0, nil, 0)
        parser.current_section[:modifiers][:foreground_colour].to_s.should == "[255, 0, 255]"
      end

      it 'sets the background colour' do
        doc.colour_table << RubyRTF::Colour.new(255, 0, 255)
        parser.handle_control(:cb, 0, nil, 0)
        parser.current_section[:modifiers][:background_colour].to_s.should == "[255, 0, 255]"
      end
    end

    context 'justification' do
      it 'handles left justify' do
        parser.handle_control(:ql, nil, nil, 0)
        parser.current_section[:modifiers][:justification].should == :left
      end

      it 'handles right justify' do
        parser.handle_control(:qr, nil, nil, 0)
        parser.current_section[:modifiers][:justification].should == :right
      end

      it 'handles full justify' do
        parser.handle_control(:qj, nil, nil, 0)
        parser.current_section[:modifiers][:justification].should == :full
      end

      it 'handles centered' do
        parser.handle_control(:qc, nil, nil, 0)
        parser.current_section[:modifiers][:justification].should == :center
      end
    end

    context 'indenting' do
      it 'handles first line indent' do
        parser.handle_control(:fi, 1000, nil, 0)
        parser.current_section[:modifiers][:first_line_indent].should == 50
      end

      it 'handles left indent' do
        parser.handle_control(:li, 1000, nil, 0)
        parser.current_section[:modifiers][:left_indent].should == 50
      end

      it 'handles right indent' do
        parser.handle_control(:ri, 1000, nil, 0)
        parser.current_section[:modifiers][:right_indent].should == 50
      end
    end

    context 'margins' do
      it 'handles left margin' do
        parser.handle_control(:margl, 1000, nil, 0)
        parser.current_section[:modifiers][:left_margin].should == 50
      end

      it 'handles right margin' do
        parser.handle_control(:margr, 1000, nil, 0)
        parser.current_section[:modifiers][:right_margin].should == 50
      end

      it 'handles top margin' do
        parser.handle_control(:margt, 1000, nil, 0)
        parser.current_section[:modifiers][:top_margin].should == 50
      end

      it 'handles bottom margin' do
        parser.handle_control(:margb, 1000, nil, 0)
        parser.current_section[:modifiers][:bottom_margin].should == 50
      end
    end

    context 'paragraph spacing' do
      it 'handles space before' do
        parser.handle_control(:sb, 1000, nil, 0)
        parser.current_section[:modifiers][:space_before].should == 50
      end

      it 'handles space after' do
        parser.handle_control(:sa, 1000, nil, 0)
        parser.current_section[:modifiers][:space_after].should == 50
      end
    end

    context 'non breaking space' do
      it 'handles :~' do
        parser.current_section[:text] = "end."
        parser.handle_control(:~, nil, nil, 0)
        doc.sections.last[:modifiers][:nbsp].should == true
        doc.sections.last[:text].should == " "
      end
    end
  end

  context 'sections' do
    it 'has sections' do
      doc.sections.should_not be_nil
    end

    it 'sets an initial section' do
      parser.current_section.should_not be_nil
    end

    context '#add_section!' do
      it 'does not add a section if the current :text is empty' do
        d = parser
        d.add_section!
        doc.sections.length.should == 0
      end

      it 'adds a section of the current section has text' do
        d = parser
        d.current_section[:text] = "Test"
        d.add_section!
        doc.sections.length.should == 1
      end

      it 'inherits the modifiers from the parent section' do
        d = parser
        d.current_section[:modifiers][:bold] = true
        d.current_section[:modifiers][:italics] = true
        d.current_section[:text] = "New text"

        d.add_section!

        d.current_section[:modifiers][:underline] = true

        sections = doc.sections
        sections.first[:modifiers].should == {:bold => true, :italics => true}
        d.current_section[:modifiers].should == {:bold => true, :italics => true, :underline => true}
      end
    end

    context '#reset_current_section!' do
      it 'resets the current sections modifiers' do
        d = parser
        d.current_section[:modifiers] = {:bold => true, :italics => true}
        d.current_section[:text] = "New text"

        d.add_section!
        d.reset_current_section!
        d.current_section[:modifiers][:underline] = true

        sections = doc.sections
        sections.first[:modifiers].should == {:bold => true, :italics => true}
        d.current_section[:modifiers].should == {:underline => true}
      end
    end

    context '#remove_last_section!' do
      it 'removes the last section' do
        d = parser
        d.current_section[:modifiers] = {:bold => true, :italics => true}
        d.current_section[:text] = "New text"

        d.add_section!

        d.current_section[:modifiers][:underline] = true

        doc.sections.length.should == 1
        doc.sections.first[:text].should == 'New text'
      end
    end

    context 'tables' do
      def compare_table_results(table, data)
        table.rows.length.should == data.length

        data.each_with_index do |row, idx|
          end_positions = table.rows[idx].end_positions
          row[:end_positions].each_with_index do |size, cidx|
            end_positions[cidx].should == size
          end

          cells = table.rows[idx].cells
          cells.length.should == row[:values].length

          row[:values].each_with_index do |items, vidx|
            sects = cells[vidx].sections
            items.each_with_index do |val, iidx|
              sects[iidx][:text].should == val
            end
          end
        end
      end

      it 'parses a single row/column table' do
        src = '{\rtf1 Before Table' +
                '\trowd\trgaph180\cellx1440' +
                '\pard\intbl fee.\cell\row ' +
                'After table}'
        d = parser.parse(src)

        sect = d.sections
        sect.length.should == 3
        sect[0][:text].should == 'Before Table'
        sect[2][:text].should == 'After table'

        sect[1][:modifiers][:table].should_not be_nil
        table = sect[1][:modifiers][:table]

        compare_table_results(table, [{:end_positions => [72], :values => [['fee.']]}])
      end

      it 'parses a \trgaph180' do
        src = '{\rtf1 Before Table' +
                '\trowd\trgaph180\cellx1440' +
                '\pard\intbl fee.\cell\row ' +
                'After table}'
        d = parser.parse(src)

        table = d.sections[1][:modifiers][:table]
        table.half_gap.should == 9
      end

      it 'parses a \trleft240' do
        src = '{\rtf1 Before Table' +
                '\trowd\trgaph180\trleft240\cellx1440' +
                '\pard\intbl fee.\cell\row ' +
                'After table}'
        d = parser.parse(src)

        table = d.sections[1][:modifiers][:table]
        table.left_margin.should == 12
      end

      it 'parses a single row with multiple columns' do
        src = '{\rtf1 Before Table' +
                '\trowd\trgaph180\cellx1440\cellx2880\cellx1000' +
                '\pard\intbl fee.\cell' +
                '\pard\intbl fie.\cell' +
                '\pard\intbl foe.\cell\row ' +
                'After table}'
        d = parser.parse(src)

        sect = d.sections

        sect.length.should == 3
        sect[0][:text].should == 'Before Table'
        sect[2][:text].should == 'After table'

        sect[1][:modifiers][:table].should_not be_nil
        table = sect[1][:modifiers][:table]

        compare_table_results(table, [{:end_positions => [72, 144, 50], :values => [['fee.'], ['fie.'], ['foe.']]}])
      end

      it 'parses multiple rows and multiple columns' do
        src = '{\rtf1 \strike Before Table' +
                '\trowd\trgaph180\cellx1440\cellx2880\cellx1000' +
                '\pard\intbl\ul fee.\cell' +
                '\pard\intbl\i fie.\cell' +
                '\pard\intbl\b foe.\cell\row ' +
                '\trowd\trgaph180\cellx1000\cellx1440\cellx2880' +
                '\pard\intbl\i foo.\cell' +
                '\pard\intbl\b bar.\cell' +
                '\pard\intbl\ul baz.\cell\row ' +
                'After table}'
        d = parser.parse(src)

        sect = d.sections
        sect.length.should == 3
        sect[0][:text].should == 'Before Table'
        sect[2][:text].should == 'After table'

        sect[1][:modifiers][:table].should_not be_nil
        table = sect[1][:modifiers][:table]

        compare_table_results(table, [{:end_positions => [72, 144, 50], :values => [['fee.'], ['fie.'], ['foe.']]},
                                      {:end_positions => [50, 72, 144], :values => [['foo.'], ['bar.'], ['baz.']]}])
      end

      it 'parses a grouped table' do
        src = '{\rtf1 \strike Before Table' +
                '{\trowd\trgaph180\cellx1440\cellx2880\cellx1000' +
                  '\pard\intbl\ul fee.\cell' +
                  '\pard\intbl\i fie.\cell' +
                  '\pard\intbl\b foe.\cell\row}' +
                '{\trowd\trgaph180\cellx1000\cellx1440\cellx2880' +
                  '\pard\intbl\i foo.\cell' +
                  '\pard\intbl\b bar.\cell' +
                  '\pard\intbl\ul baz.\cell\row}' +
                'After table}'
        d = parser.parse(src)

        sect = d.sections
        sect.length.should == 3
        sect[0][:text].should == 'Before Table'
        sect[2][:text].should == 'After table'

        sect[1][:modifiers][:table].should_not be_nil
        table = sect[1][:modifiers][:table]

        compare_table_results(table, [{:end_positions => [72, 144, 50], :values => [['fee.'], ['fie.'], ['foe.']]},
                                      {:end_positions => [50, 72, 144], :values => [['foo.'], ['bar.'], ['baz.']]}])
      end

      it 'parses a new line inside a table cell' do
        src = '{\rtf1 Before Table' +
                '\trowd\trgaph180\cellx1440' +
                '\pard\intbl fee.\line fie.\cell\row ' +
                'After table}'
        d = parser.parse(src)

        sect = d.sections
        sect.length.should == 3
        sect[0][:text].should == 'Before Table'
        sect[2][:text].should == 'After table'
        table = sect[1][:modifiers][:table]

        compare_table_results(table, [{:end_positions => [72], :values => [["fee.", "\n", "fie."]]}])
      end

      it 'parses a new line inside a table cell' do
        src = '{\rtf1 Before Table' +
                '\trowd\trgaph180\cellx1440\cellx2880\cellx1000' +
                '\pard\intbl fee.\cell' +
                '\pard\intbl\cell' +
                '\pard\intbl fie.\cell\row ' +
                'After table}'
        d = parser.parse(src)

        sect = d.sections
        sect.length.should == 3
        sect[0][:text].should == 'Before Table'
        sect[2][:text].should == 'After table'
        table = sect[1][:modifiers][:table]

        compare_table_results(table, [{:end_positions => [72, 144, 50], :values => [["fee."], [""], ["fie."]]}])
      end

      it 'parses a grouped cell' do
        src = '{\rtf1 Before Table\trowd\cellx1440\cellx2880\cellx1000 \pard ' +
                '{\fs20 Familiar }{\cell }' +
                '{\fs20 Alignment }{\cell }' +
                '\pard \intbl {\fs20 Arcane Spellcaster Level}{\cell }' +
                '\pard {\b\fs18 \trowd \trgaph108\trleft-108\cellx1000\row }After table}'
        d = parser.parse(src)

        sect = d.sections

        sect.length.should == 3
        sect[0][:text].should == 'Before Table'
        sect[2][:text].should == 'After table'
        table = sect[1][:modifiers][:table]

        compare_table_results(table, [{:end_positions => [72, 144, 50],
                                       :values => [["Familiar "], ["Alignment "], ['Arcane Spellcaster Level']]}])
      end

      it 'parses cells' do
        src = '{\rtf1\trowd\trgaph108\trleft-108\cellx1440\cellx2880' +
                '\intbl{\fs20 Familiar }{\cell }' +
                '{\fs20 Alignment }{\cell }}'

        d = parser.parse(src)
        table = d.sections[0][:modifiers][:table]

        compare_table_results(table, [{:end_positions => [72, 144], :values => [['Familiar '], ['Alignment ']]}])
      end

      it 'parses blank rows' do
        src = '{\rtf1\trowd \trgaph108\trleft-108\cellx1440' +
                '\intbl{\fs20 Familiar }{\cell }' +
                '\pard\plain \intbl {\trowd \trgaph108\trleft-108\cellx1440\row } ' +
                'Improved animal}'
        d = parser.parse(src)

        sect = d.sections
        sect.length.should == 2
        sect[1][:text].should == ' Improved animal'
        sect[1][:modifiers].should == {}

        table = sect[0][:modifiers][:table]
        compare_table_results(table, [{:end_positions => [72], :values => [['Familiar ']]}])
      end
    end
  end
end
