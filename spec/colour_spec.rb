require 'spec_helper'

describe RubyRTF::Colour do
  it 'also responds to Color' do
    lambda { RubyRTF::Color.new }.should_not raise_error
  end

  it 'returns the rgb when to_s is called' do
    c = RubyRTF::Colour.new(255, 200, 199)
    c.to_s.should == '[255, 200, 199]'
  end
end