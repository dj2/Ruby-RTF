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

  it 'parses a default font (\deffN)'

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

  context '#handle_control' do
    it 'dispatches a font table command' do
      doc_mock = mock("document")
      RubyRTF::Parser.should_receive(:parse_font_table).with("doc", 5, doc_mock)
      RubyRTF::Parser.handle_control(:fonttbl, nil, "doc", 5, doc_mock)
    end
  end

  context 'character set' do
    %w(ansi mac pc pca).each do |type|
      it "accepts #{type}"
    end
  end

  context 'font table' do
    it 'sets the font table into the document' do
      src = '{\rtf1{\fonttbl{\f0\froman Times;}{\f1\fnil Arial;}}}'
      doc = RubyRTF::Parser.parse(src)

      font = doc.font_table['0']
      font.family_command.should == :roman
      font.name.should == 'Times'
    end
  end

  context '#handle_font_table' do
    let(:doc) { RubyRTF::Document.new }

    it 'parses a font table' do
      src = '{\f0\froman Times New Roman;}{\f1\fnil Arial;}}}'
      RubyRTF::Parser.parse_font_table(src, 0, doc)
      tbl = doc.font_table

      tbl.keys.length.should == 2
      tbl['0'].family_command.should == :roman
      tbl['0'].name.should == 'Times New Roman'

      tbl['1'].family_command.should == :nil
      tbl['1'].name.should == 'Arial'
    end

    it 'the family command is optional'
    it 'does not require the numbering to be incremental'
    it 'sets current pos to the closing }'
  end

  context 'colour table' do
  end

  context 'stylesheet' do
  end

  context 'document info' do
  end
end