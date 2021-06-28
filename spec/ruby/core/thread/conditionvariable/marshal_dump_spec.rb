require_relative '../../../spec_helper'
require 'thread'

describe "Thread::ConditionVariable#marshal_dump" do
  it "raises a TypeError" do
    cv = Thread::ConditionVariable.new
    -> { cv.marshal_dump }.should raise_error(TypeError, /can't dump/)
  end
end
