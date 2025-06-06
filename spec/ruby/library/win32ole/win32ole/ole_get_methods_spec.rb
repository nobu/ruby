require_relative "../../../spec_helper"
platform_is :windows do
  require_relative '../fixtures/classes'

  describe "WIN32OLE#ole_get_methods" do

    before :each do
      @win32ole = WIN32OLESpecs.new_ole('Shell.Application')
    end

    it "returns an array of WIN32OLE::Method objects" do
      @win32ole.ole_get_methods.all? {|m| m.kind_of? WIN32OLE::Method}.should be_true
    end

  end

end
