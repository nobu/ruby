require_relative '../../spec_helper'

ruby_version_is "4.1" do
  describe "Range#clamp" do
    it "returns a new Range with begin and end clamped to min and max" do
      (1..10).clamp(3, 7).should == (3..7)
      (..10).clamp(3, 7).should == (3..7)

      (1..10).clamp(20, 30).should == (20...20)
      (1..10).clamp(-10, 0).should == (0...0)
      (..10).clamp(20, 30).should == (20...20)
    end

    it "returns a new Range with begin and end clamped to a Range" do
      (1..10).clamp(3..7).should == (3..7)
      (1..5).clamp(3...7).should == (3..5)

      (1..10).clamp(20..30).should == (20...20)
      (1..10).clamp(-10..0).should == (0...0)
      (..10).clamp(20..30).should == (20...20)
    end

    it "preserves exclusive end for finite exclusive receiver in min/max form" do
      (1...10).clamp(3, 7).should == (3...7)
    end

    it "does not preserve exclusive end for endless exclusive receiver clamped to a finite max" do
      (0...).clamp(0, 10).should == (0..10)
    end

    it "uses exclusive end when the returned end is the excluded end of the argument Range" do
      (1..10).clamp(3...7).should == (3...7)
      (1..10).clamp(3...10).should == (3...10)
      (..10).clamp(3...7).should == (3...7)
    end

    it "does not use exclusive end when the returned end is not the excluded end of the argument Range" do
      (1..5).clamp(3...7).should == (3..5)
      (..5).clamp(3...7).should == (3..5)
      (1..10).clamp(3...).should == (3..10)
    end

    it "handles beginless and endless argument Ranges" do
      (1..10).clamp(..7).should == (1..7)
      (1..10).clamp(...7).should == (1...7)
      (1..5).clamp(...7).should == (1..5)

      (1..10).clamp(3..).should == (3..10)
      (1..).clamp(3..).should == (3..)
      (1...).clamp(3...).should == (3...)
    end

    it "returns an inclusive point Range when begin and end are clamped to different equal bounds" do
      (1..10).clamp(3, 3).should == (3..3)
      (1..10).clamp(3..3).should == (3..3)
    end

    it "returns an empty Range when begin and end are clamped to the same side" do
      (1..2).clamp(3, 3).should == (3...3)
      (4..10).clamp(3, 3).should == (3...3)
    end

    it "raises ArgumentError when min and max are not comparable" do
      -> { (1..3).clamp(1, "z") }.should.raise(ArgumentError)
      -> { (1..3).clamp("a", "z") }.should.raise(ArgumentError)
    end

    it "raises ArgumentError when min is greater than max" do
      -> { (1..3).clamp(2, 1) }.should.raise(ArgumentError)
      -> { (1..3).clamp(2..1) }.should.raise(ArgumentError)
    end

    it "raises TypeError when the single argument is not a Range" do
      -> { (1..3).clamp(1) }.should.raise(TypeError)
    end
  end
end
