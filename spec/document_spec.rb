require 'spec_helper'

describe RubyRTF::Document do
  it 'provides a font table' do
    doc = RubyRTF::Document.new
    table = nil
    lambda { table = doc.font_table }.should_not raise_error
    table.should_not be_nil
  end

  it 'provides a colour table'
  it 'provides a stylesheet'

  context 'defaults to' do
    it 'character set ansi'
    it 'font 0'
  end
end