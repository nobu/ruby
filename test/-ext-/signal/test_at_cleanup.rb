# frozen_string_literal: true
require 'test/unit'

class Test_Signal < Test::Unit::TestCase
  if Signal.list.key?("TERM")
    def test_term_at_vm_cleanup
      output = [
        "Sending signal",
        "Trying to release GVL",
        "GVL released!",
        "After releasing GVL",
      ]
      assert_in_out_err(%w[-r-test-/signal], "#{<<~"begin;"}\n#{<<~'end;'}", output)
      begin;
        Signal.trap("TERM") { puts "Hello, world" }
        Bug::Signal::AtCleanup.new
      end;
    end
  end
end
