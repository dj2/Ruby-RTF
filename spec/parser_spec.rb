require 'spec_helper'

describe RubyRTF::Parser do
  it 'parses hello world' do
    src = '{\rtf1\ansi\deff0 {\fonttbl {\f0 Times New Roman;}}\f0 \fs60 Hello, World!}'
    lambda { RubyRTF::Parser.parse(src) }.should_not raise_error
  end

  it 'returns a RTF::Document' do
    src = '{\rtf1\ansi\deff0 {\fonttbl {\f0 Times New Roman;}}\f0 \fs60 Hello, World!}'
    doc = RubyRTF::Parser.parse(src)
    doc.is_a?(RubyRTF::Document).should be_true
  end

  it 'parses a default font (\deffN)' do
    src = '{\rtf1\ansi\deff10 {\fonttbl {\f10 Times New Roman;}}\f0 \fs60 Hello, World!}'
    doc = RubyRTF::Parser.parse(src)
    doc.default_font.should == 10
  end

  context 'invalid document' do
    it 'raises exception if \rtf is missing' do
      src = '{\ansi\deff0 {\fonttbl {\f0 Times New Roman;}}\f0 \fs60 Hello, World!}'
      lambda { RubyRTF::Parser.parse(src) }.should raise_error(RubyRTF::InvalidDocument)
    end

    it 'raises exception if the document does not start with \rtf' do
      src = '{\ansi\deff0\rtf1 {\fonttbl {\f0 Times New Roman;}}\f0 \fs60 Hello, World!}'
      lambda { RubyRTF::Parser.parse(src) }.should raise_error(RubyRTF::InvalidDocument)
    end

    it 'raises exception if the {}s are unbalanced' do
      src = '{\rtf1\ansi\deff0 {\fonttbl {\f0 Times New Roman;}\f0 \fs60 Hello, World!}'
      lambda { RubyRTF::Parser.parse(src) }.should raise_error(RubyRTF::InvalidDocument)
    end
  end

  context '#parse' do
    it 'parses text into the current section' do
      src = '{\rtf1\ansi\deff10 {\fonttbl {\f10 Times New Roman;}}\f0 \fs60 Hello, World!}'
      doc = RubyRTF::Parser.parse(src)
      doc.sections.first[:text].should == 'Hello, World!'
    end

    it 'adds a new section on {' do
      src = '{\rtf1 \fs60 Hello {\fs30 World}}'
      doc = RubyRTF::Parser.parse(src)
      doc.sections.first[:modifiers][:font_size].should == 30
      doc.sections.first[:text].should == 'Hello '

      doc.sections.last[:modifiers][:font_size].should == 15
      doc.sections.last[:text].should == 'World'
    end

    it 'adds a new section on }' do
      src = '{\rtf1 \fs60 Hello {\fs30 World}\fs12 Goodbye, cruel world.}'
      doc = RubyRTF::Parser.parse(src)
      section = doc.sections
      section[0][:modifiers][:font_size].should == 30
      section[0][:text].should == 'Hello '

      section[1][:modifiers][:font_size].should == 15
      section[1][:text].should == 'World'

      section[2][:modifiers][:font_size].should == 6
      section[2][:text].should == 'Goodbye, cruel world.'
    end

    it 'inherits properly over {} groups' do
      src = '{\rtf1 \b\fs60 Hello {\i\fs30 World}\ul Goodbye, cruel world.}'
      doc = RubyRTF::Parser.parse(src)
      section = doc.sections
      section[0][:modifiers][:font_size].should == 30
      section[0][:modifiers][:bold].should be_true
      section[0][:modifiers].has_key?(:italic).should be_false
      section[0][:modifiers].has_key?(:underline).should be_false
      section[0][:text].should == 'Hello '

      section[1][:modifiers][:font_size].should == 15
      section[1][:modifiers][:italic].should be_true
      section[1][:modifiers][:bold].should be_true
      section[1][:modifiers].has_key?(:underline).should be_false
      section[1][:text].should == 'World'

      section[2][:modifiers][:font_size].should == 30
      section[2][:modifiers][:bold].should be_true
      section[2][:modifiers][:underline].should be_true
      section[2][:modifiers].has_key?(:italic).should be_false
      section[2][:text].should == 'Goodbye, cruel world.'
    end
  end

  context '#parse_control' do
    it 'parses a normal control' do
      RubyRTF::Parser.parse_control("rtf")[0, 2].should == [:rtf, nil]
    end

    it 'parses a control with a value' do
      RubyRTF::Parser.parse_control("f2")[0, 2].should == [:f, 2]
    end

    context 'unicode' do
      %w(u21487* u21487).each do |code|
        it "parses #{code}" do
          RubyRTF::Parser.parse_control(code)[0, 2].should == [:u, 21487]
        end
      end

      %w(u-21487* u-21487).each do |code|
        it "parses #{code}" do
          RubyRTF::Parser.parse_control(code)[0, 2].should == [:u, -21487]
        end
      end
    end

    it 'parses a hex control' do
      RubyRTF::Parser.parse_control("'7e")[0, 2].should == [:hex, '~']
    end

    it 'parses a hex control with a string after it' do
      ctrl, val, current_pos = RubyRTF::Parser.parse_control("'7e25")
      ctrl.should == :hex
      val.should == '~'
      current_pos.should == 3
    end

    [' ', '{', '}', '\\', "\r", "\n"].each do |stop|
      it "stops at a #{stop}" do
        RubyRTF::Parser.parse_control("rtf#{stop}test")[0, 2].should == [:rtf, nil]
      end
    end

    it 'handles a non-zero current position' do
      RubyRTF::Parser.parse_control('Test ansi test', 5)[0, 2].should == [:ansi, nil]
    end

    it 'advances the current positon' do
      RubyRTF::Parser.parse_control('Test ansi{test', 5).last.should == 9
    end

    it 'advances the current positon past the optional space' do
      RubyRTF::Parser.parse_control('Test ansi test', 5).last.should == 10
    end
  end

  context 'character set' do
    %w(ansi mac pc pca).each do |type|
      it "accepts #{type}" do
        src = "{\\rtf1\\#{type}\\deff0 {\\fonttbl {\\f0 Times New Roman;}}\\f0 \\fs60 Hello, World!}"
        doc = RubyRTF::Parser.parse(src)
        doc.character_set.should == type.to_sym
      end
    end
  end

  context 'font table' do
    it 'sets the font table into the document' do
      src = '{\rtf1{\fonttbl{\f0\froman Times;}{\f1\fnil Arial;}}}'
      doc = RubyRTF::Parser.parse(src)

      font = doc.font_table[0]
      font.family_command.should == :roman
      font.name.should == 'Times'
    end

    context '#parse_font_table' do
      let(:doc) { RubyRTF::Document.new }

      it 'parses a font table' do
        src = '{\f0\froman Times New Roman;}{\f1\fnil Arial;}}}'
        RubyRTF::Parser.parse_font_table(src, 0, doc)
        tbl = doc.font_table

        tbl.length.should == 2
        tbl[0].family_command.should == :roman
        tbl[0].name.should == 'Times New Roman'

        tbl[1].family_command.should == :nil
        tbl[1].name.should == 'Arial'
      end

      it 'handles \r and \n in the font table' do
        src = "{\\f0\\froman Times New Roman;}\r{\\f1\\fnil Arial;}\n}}"
        RubyRTF::Parser.parse_font_table(src, 0, doc)
        tbl = doc.font_table

        tbl.length.should == 2
        tbl[0].family_command.should == :roman
        tbl[0].name.should == 'Times New Roman'

        tbl[1].family_command.should == :nil
        tbl[1].name.should == 'Arial'
      end

      it 'the family command is optional' do
        src = '{\f0 Times New Roman;}}}'
        RubyRTF::Parser.parse_font_table(src, 0, doc)
        tbl = doc.font_table
        tbl[0].family_command.should == :nil
        tbl[0].name.should == 'Times New Roman'
      end

      it 'does not require the numbering to be incremental' do
        src = '{\f77\froman Times New Roman;}{\f3\fnil Arial;}}}'
        RubyRTF::Parser.parse_font_table(src, 0, doc)
        tbl = doc.font_table

        tbl[77].family_command.should == :roman
        tbl[77].name.should == 'Times New Roman'

        tbl[3].family_command.should == :nil
        tbl[3].name.should == 'Arial'
      end

      it 'accepts the \falt command' do
        src = '{\f0\froman Times New Roman{\*\falt Courier New};}}'
        RubyRTF::Parser.parse_font_table(src, 0, doc)
        tbl = doc.font_table
        tbl[0].name.should == 'Times New Roman'
        tbl[0].alternate_name.should == 'Courier New'
      end

      it 'sets current pos to the closing }' do
        src = '{\f0\froman Times New Roman{\*\falt Courier New};}}'
        RubyRTF::Parser.parse_font_table(src, 0, doc).should == (src.length - 1)
      end

      it 'accepts the panose command' do
        src = '{\f0\froman\fcharset0\fprq2{\*\panose 02020603050405020304}Times New Roman{\*\falt Courier New};}}'
        RubyRTF::Parser.parse_font_table(src, 0, doc)
        tbl = doc.font_table
        tbl[0].panose.should == '02020603050405020304'
        tbl[0].name.should == 'Times New Roman'
        tbl[0].alternate_name.should == 'Courier New'
      end

      %w(flomajor fhimajor fdbmajor fbimajor flominor fhiminor fdbminor fbiminor).each do |type|
        it "handles theme font type: #{type}" do
          src = "{\\f0\\#{type} Times New Roman;}}"
          RubyRTF::Parser.parse_font_table(src, 0, doc)
          tbl = doc.font_table
          tbl[0].name.should == 'Times New Roman'
          tbl[0].theme.should == type[1..-1].to_sym
        end
      end

      [[0, :default], [1, :fixed], [2, :variable]].each do |pitch|
        it 'parses pitch information' do
          src = "{\\f0\\fprq#{pitch.first} Times New Roman;}}"
          RubyRTF::Parser.parse_font_table(src, 0, doc)
          tbl = doc.font_table
          tbl[0].name.should == 'Times New Roman'
          tbl[0].pitch.should == pitch.last
        end
      end

      it 'parses the non-tagged font name' do
        src = '{\f0{\*\fname Arial;}Times New Roman;}}'
        RubyRTF::Parser.parse_font_table(src, 0, doc)
        tbl = doc.font_table
        tbl[0].name.should == 'Times New Roman'
        tbl[0].non_tagged_name.should == 'Arial'
      end

      it 'parses the charset' do
        src = '{\f0\fcharset87 Times New Roman;}}'
        RubyRTF::Parser.parse_font_table(src, 0, doc)
        tbl = doc.font_table
        tbl[0].name.should == 'Times New Roman'
        tbl[0].character_set.should == 87
      end
    end
  end

  context 'colour table' do
    it 'sets the colour table into the document' do
      src = '{\rtf1{\colortbl\red0\green0\blue0;\red127\green2\blue255;}}'
      doc = RubyRTF::Parser.parse(src)

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
      doc = RubyRTF::Parser.parse(src)

      clr = doc.colour_table[0]
      clr.use_default?.should be_true

      clr = doc.colour_table[1]
      clr.red.should == 255
      clr.green.should == 0
      clr.blue.should == 0
    end

    context '#parse_colour_table' do
      let(:doc) { RubyRTF::Document.new }

      it 'parses \red \green \blue' do
        src = '\red2\green55\blue23;}'
        RubyRTF::Parser.parse_colour_table(src, 0, doc)
        tbl = doc.colour_table
        tbl[0].red.should == 2
        tbl[0].green.should == 55
        tbl[0].blue.should == 23
      end

      it 'handles ctintN' do
        src = '\ctint22\red2\green55\blue23;}'
        RubyRTF::Parser.parse_colour_table(src, 0, doc)
        tbl = doc.colour_table
        tbl[0].tint.should == 22
      end

      it 'handles cshadeN' do
        src = '\cshade11\red2\green55\blue23;}'
        RubyRTF::Parser.parse_colour_table(src, 0, doc)
        tbl = doc.colour_table
        tbl[0].shade.should == 11
      end

      %w(cmaindarkone cmainlightone cmaindarktwo cmainlighttwo caccentone
         caccenttwo caccentthree caccentfour caccentfive caccentsix
         chyperlink cfollowedhyperlink cbackgroundone ctextone
         cbackgroundtwo ctexttwo).each do |theme|
        it "it allows theme item #{theme}" do
          src = "\\#{theme}\\red11\\green22\\blue33;}"
          RubyRTF::Parser.parse_colour_table(src, 0, doc)
          tbl = doc.colour_table
          tbl[0].theme.should == theme[1..-1].to_sym
        end
      end

      it 'handles \r and \n' do
        src = "\\cshade11\\red2\\green55\r\n\\blue23;}"
        RubyRTF::Parser.parse_colour_table(src, 0, doc)
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
    let(:doc) { RubyRTF::Document.new }

    it 'sets the font' do
      font = RubyRTF::Font.new('Times New Roman')
      doc.font_table[0] = font

      RubyRTF::Parser.handle_control(:f, 0, nil, 0, doc)
      doc.current_section[:modifiers][:font].should == font
    end

    it 'sets the font size' do
      RubyRTF::Parser.handle_control(:fs, 61, nil, 0, doc)
      doc.current_section[:modifiers][:font_size].should == 30.5
    end

    it 'sets bold' do
      RubyRTF::Parser.handle_control(:b, nil, nil, 0, doc)
      doc.current_section[:modifiers][:bold].should be_true
    end

    it 'sets underline' do
      RubyRTF::Parser.handle_control(:ul, nil, nil, 0, doc)
      doc.current_section[:modifiers][:underline].should be_true
    end

    it 'sets italic' do
      RubyRTF::Parser.handle_control(:i, nil, nil, 0, doc)
      doc.current_section[:modifiers][:italic].should be_true
    end

    %w(rquote lquote).each do |quote|
      it "sets a #{quote}" do
        doc.current_section[:text] = 'My code'
        RubyRTF::Parser.handle_control(quote.to_sym, nil, nil, 0, doc)
        doc.remove_current_section!
        doc.current_section[:text].should == "'"
        doc.current_section[:modifiers][quote.to_sym].should be_true
      end
    end

    %w(rdblquote ldblquote).each do |quote|
      it "sets a #{quote}" do
        doc.current_section[:text] = 'My code'
        RubyRTF::Parser.handle_control(quote.to_sym, nil, nil, 0, doc)
        doc.remove_current_section!
        doc.current_section[:text].should == '"'
        doc.current_section[:modifiers][quote.to_sym].should be_true
      end
    end

    it 'sets a hex character' do
      doc.current_section[:text] = 'My code'
      RubyRTF::Parser.handle_control(:hex, '~', nil, 0, doc)
      doc.current_section[:text].should == 'My code~'
    end

    context 'new line' do
      ['line', '\n'].each do |type|
        it "sets from #{type}" do
          doc.current_section[:text] = "end."
          RubyRTF::Parser.handle_control(type.to_sym, nil, nil, 0, doc)
          doc.remove_current_section!
          doc.current_section[:modifiers][:newline].should be_true
          doc.current_section[:text].should == "\n"
        end
      end

      it 'ignores \r' do
        doc.current_section[:text] = "end."
        RubyRTF::Parser.handle_control(:'\r', nil, nil, 0, doc)
        doc.current_section[:text].should == "end."
      end
    end

    it 'inserts a \tab' do
      doc.current_section[:text] = "end."
      RubyRTF::Parser.handle_control(:tab, nil, nil, 0, doc)
      doc.remove_current_section!
      doc.current_section[:modifiers][:tab].should be_true
      doc.current_section[:text].should == "\t"
    end

    context 'escapes' do
      ['{', '}', '\\'].each do |escape|
        it "inserts an escaped #{escape}" do
          doc.current_section[:text] = "end."
          RubyRTF::Parser.handle_control(escape.to_sym, nil, nil, 0, doc)
          doc.current_section[:text].should == "end.#{escape}"
        end
      end
    end

    it 'adds a new section for a par command' do
      doc.current_section[:text] = 'end.'
      RubyRTF::Parser.handle_control(:par, nil, nil, 0, doc)
      doc.current_section[:text].should == ""
    end

    it 'resets the current sections formattion to default' do
      doc.current_section[:modifiers][:bold] = true
      doc.current_section[:modifiers][:italic] = true
      RubyRTF::Parser.handle_control(:pard, nil, nil, 0, doc)

      doc.current_section[:modifiers].has_key?(:bold).should be_false
      doc.current_section[:modifiers].has_key?(:italic).should be_false
    end
  end
end
