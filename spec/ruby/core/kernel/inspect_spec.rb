require_relative '../../spec_helper'
require_relative 'fixtures/classes'

describe "Kernel#inspect" do
  it "returns a String" do
    Object.new.inspect.should be_an_instance_of(String)
  end

  it "does not call #to_s if it is defined" do
    # We must use a bare Object here
    obj = Object.new
    inspected = obj.inspect

    obj.stub!(:to_s).and_return("to_s'd")

    obj.inspect.should == inspected
  end

  it "returns a String with the object class and object_id encoded" do
    obj = Object.new
    obj.inspect.should =~ /^#<Object:0x[0-9a-f]+>$/
  end

  it "returns a String for an object without #class method" do
    obj = Object.new
    class << obj
      undef_method :class
    end
    obj.inspect.should be_kind_of(String)
  end

  ruby_version_is "3.5" do
    it "calls #inspect_instance_variables method" do
      obj = Object.new
      obj.instance_eval do
        @host = "localhost"
        @user = "root"
        @password = "hunter2"
        def inspect_instance_variables
          %i[@host @user]
        end
      end
      inspected = obj.inspect
      inspected.should include('@host="localhost"')
      inspected.should include('@user="root"')
      inspected.should_not include('@password=')
    end
  end
end
