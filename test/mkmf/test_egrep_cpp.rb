# frozen_string_literal: false
require_relative 'base'
require 'tempfile'

class TestMkmf
  class TestEgrepCpp < TestMkmf
    def test_egrep_cpp
      assert_equal(true, egrep_cpp(/ruby_init/, ""), MKMFLOG)
    end

    def test_not_have_func
      assert_equal(false, egrep_cpp(/never match/, ""), MKMFLOG)
    end

    def test_cxx_egrep_cpp
      assert_equal(true, MakeMakefile["C++"].egrep_cpp(/^ok/, <<~SRC), MKMFLOG)
      #ifdef __cplusplus
      ok
      #else
      #error not C++
      #endif
      SRC
    end
  end
end
