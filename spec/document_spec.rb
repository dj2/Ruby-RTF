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

  context 'sections' do
    it 'has sections' do
      RubyRTF::Document.new.sections.should_not be_nil
    end

    it 'sets an initial section' do
      RubyRTF::Document.new.current_section.should_not be_nil
    end

    context '#add_section!' do
      it 'does not add a section if the current :text is empty' do
        d = RubyRTF::Document.new
        d.add_section!
        d.sections.length.should == 1
      end

      it 'adds a section of the current section has text' do
        d = RubyRTF::Document.new
        d.current_section[:text] = "Test"
        d.add_section!
        d.sections.length.should == 2
      end

      it 'inherits the modifiers from the parent section' do
        d = RubyRTF::Document.new
        d.current_section[:modifiers][:bold] = true
        d.current_section[:modifiers][:italics] = true
        d.current_section[:text] = "New text"

        d.add_section!

        d.current_section[:modifiers][:underline] = true

        sections = d.sections
        sections.first[:modifiers].should == {:bold => true, :italics => true}
        sections.last[:modifiers].should == {:bold => true, :italics => true, :underline => true}
      end
    end

    context '#reset_section!' do
      it 'resets the current sections modifiers' do
        d = RubyRTF::Document.new
        d.current_section[:modifiers] = {:bold => true, :italics => true}
        d.current_section[:text] = "New text"

        d.add_section!
        d.reset_section!
        d.current_section[:modifiers][:underline] = true

        sections = d.sections
        sections.first[:modifiers].should == {:bold => true, :italics => true}
        sections.last[:modifiers].should == {:underline => true}
      end
    end

    context '#remove_last_section!' do
      it 'removes the last section' do
        d = RubyRTF::Document.new
        d.current_section[:modifiers] = {:bold => true, :italics => true}
        d.current_section[:text] = "New text"

        d.add_section!

        d.current_section[:modifiers][:underline] = true

        d.remove_current_section!
        d.sections.length.should == 1
        d.sections.first[:text].should == 'New text'
      end
    end
  end
end