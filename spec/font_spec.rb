require 'spec_helper'

describe RubyRTF::Font do
  let(:font) { RubyRTF::Font.new }

  it 'has a name' do
    font.name = 'Arial'
    font.name.should == 'Arial'
  end

  it 'has a command' do
    font.family_command = :swiss
    font.family_command.should == :swiss
  end
end