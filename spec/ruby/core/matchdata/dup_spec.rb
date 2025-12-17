require_relative '../../spec_helper'

describe "MatchData#dup" do
  it "duplicates the match data" do
    original = /ll/.match("hello")
    ruby_version_is ""..."4.0" do
      original.instance_variable_set(:@custom_ivar, 42)
    end
    duplicate = original.dup

    ruby_version_is ""..."4.0" do
      duplicate.instance_variable_get(:@custom_ivar).should == 42
    end
    original.regexp.should == duplicate.regexp
    original.string.should == duplicate.string
    original.offset(0).should == duplicate.offset(0)
  end
end
