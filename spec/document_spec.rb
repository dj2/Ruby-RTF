require 'spec_helper'

describe RubyRTF::Document do
  it 'provides a font table' do
    doc = RubyRTF::Document.new
    table = nil
    lambda { table = doc.font_table }.should_not raise_error
    table.should_not be_nil
  end

  context 'colour table' do
    it 'provides a colour table' do
      doc = RubyRTF::Document.new
      tbl = nil
      lambda { tbl = doc.colour_table }.should_not raise_error
      tbl.should_not be_nil
    end

    it 'provdies access as color table' do
      doc = RubyRTF::Document.new
      tbl = nil
      lambda { tbl = doc.color_table }.should_not raise_error
      tbl.should == doc.colour_table
    end
  end

  it 'provides a stylesheet'

  context 'defaults to' do
    it 'character set ansi' do
      RubyRTF::Document.new.character_set.should == :ansi
    end

    it 'font 0' do
      RubyRTF::Document.new.default_font.should == 0
    end
  end
end