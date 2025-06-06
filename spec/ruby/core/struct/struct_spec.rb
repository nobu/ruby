require_relative '../../spec_helper'
require_relative 'fixtures/classes'

describe "Struct" do
  it "includes Enumerable" do
    Struct.include?(Enumerable).should == true
  end
end

describe "Struct anonymous class instance methods" do
  it "includes Enumerable" do
    StructClasses::Car.include?(Enumerable).should == true
  end

  it "reader method should be a synonym for []" do
    klass = Struct.new(:clock, :radio)
    alarm = klass.new(true)
    alarm.clock.should == alarm[:clock]
    alarm.radio.should == alarm['radio']
  end

  it "reader method should not interfere with undefined methods" do
    car = StructClasses::Car.new('Ford', 'Ranger')
    -> { car.something_weird }.should raise_error(NoMethodError)
  end

  it "writer method be a synonym for []=" do
    car = StructClasses::Car.new('Ford', 'Ranger')
    car.model.should == 'Ranger'
    car.model = 'F150'
    car.model.should == 'F150'
    car[:model].should == 'F150'
    car['model'].should == 'F150'
    car[1].should == 'F150'
  end

  it "writer methods raise a FrozenError on a frozen struct" do
    car = StructClasses::Car.new('Ford', 'Ranger')
    car.freeze

    -> { car.model = 'Escape' }.should raise_error(FrozenError)
  end
end

describe "Struct subclasses" do
  it "can be subclassed" do
    compact = Class.new StructClasses::Car
    compact.new.class.should == compact
  end
end
