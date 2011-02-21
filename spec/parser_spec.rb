require 'spec_helper'

describe RubyRTF::Parser do
  it 'parses hello world' do
    src = '{\rtf1\ansi\deff0 {\fonttbl {\f0 Times New Roman;}}\f \fs60 Hello, World!}'
    lambda { RubyRTF::Parser.parse(src) }.should_not raise_error
  end

  it 'returns a RTF::Document' do
    src = '{\rtf1\ansi\deff0 {\fonttbl {\f0 Times New Roman;}}\f \fs60 Hello, World!}'
    doc = RubyRTF::Parser.parse(src)
    doc.is_a?(RubyRTF::Document).should be_true
  end

  it 'parses a default font (\deffN)' do
    src = '{\rtf1\ansi\deff10 {\fonttbl {\f10 Times New Roman;}}\f \fs60 Hello, World!}'
    doc = RubyRTF::Parser.parse(src)
    doc.default_font.should == 10
  end

  context 'invalid document' do
    it 'raises exception if \rtf is missing' do
      src = '{\ansi\deff0 {\fonttbl {\f0 Times New Roman;}}\f \fs60 Hello, World!}'
      lambda { RubyRTF::Parser.parse(src) }.should raise_error(RubyRTF::InvalidDocument)
    end

    it 'raises exception if the document does not start with \rtf' do
      src = '{\ansi\deff0\rtf1 {\fonttbl {\f0 Times New Roman;}}\f \fs60 Hello, World!}'
      lambda { RubyRTF::Parser.parse(src) }.should raise_error(RubyRTF::InvalidDocument)
    end

    it 'raises exception if the {}s are unbalanced' do
      src = '{\rtf1\ansi\deff0 {\fonttbl {\f0 Times New Roman;}\f \fs60 Hello, World!}'
      lambda { RubyRTF::Parser.parse(src) }.should raise_error(RubyRTF::InvalidDocument)
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
        src = "{\\rtf1\\#{type}\\deff0 {\\fonttbl {\\f0 Times New Roman;}}\\f \\fs60 Hello, World!}"
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
    end
  end

  context 'stylesheet' do
    it 'parses a stylesheet'
  end

  context 'document info' do
  end
end