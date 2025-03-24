# frozen_string_literal: false
require 'test/unit'
require '-test-/marshal/usr'

module Bug end

module Bug::Marshal
  class TestUserDef < Test::Unit::TestCase
    def test_undumpable_data
      name = "T\u{23F0 23F3}"
      c = eval("class #{name}<Bug::Marshal::UserDef;self;end")
      c.class_eval { undef _dump }
      assert_raise_with_message(TypeError, /#{name}/) {
        Marshal.dump(c.new(42))
      }

    ensure
      self.class.class_eval do
        remove_const name
      end if c
    end

    def test_unloadable_data
      name = "Unloadable\u{23F0 23F3}"
      c = eval("class #{name} < Bug::Marshal::UserDef;self;end")
      c.class_eval {
        alias _dump_data _dump
        undef _dump
      }
      d = Marshal.dump(c.new(42))
      assert_raise_with_message(TypeError, /Unloadable\u{23F0 23F3}/) {
        Marshal.load(d)
      }

    ensure
      self.class.class_eval do
        remove_const name
      end if c
    end

    def test_unloadable_userdef
      name = "Userdef\u{23F0 23F3}"
      c = eval("class #{name} < Bug::Marshal::UserDef;self;end")
      class << c
        undef _load
      end
      d = Marshal.dump(c.new(42))
      assert_raise_with_message(TypeError, /#{name}/) {
        Marshal.load(d)
      }
    ensure
      self.class.class_eval do
        remove_const name
      end if c
    end

    def test_recursive_userdef
      t = Bug::Marshal::UserDef.new(42)
      t.instance_eval {@v = t}
      assert_raise_with_message(RuntimeError, /recursive\b.*\b_dump/) do
        Marshal.dump(t)
      end
    end

    def test_unloadable_usrmarshal
      name = "Userdef\u{23F0 23F3}"
      c = eval("class #{name} < Bug::Marshal::UserDef;self;end")
      c.class_eval {
        alias marshal_dump _dump
      }
      d = Marshal.dump(c.new(42))
      assert_raise_with_message(TypeError, /#{name}/) {
        Marshal.load(d)
      }
    ensure
      self.class.class_eval do
        remove_const name
      end if c
    end
  end

  class TestUsrMarshal < Test::Unit::TestCase
    def old_dump
      @old_dump ||=
        begin
          src = "module Bug; module Marshal; class UsrMarshal; def initialize(val) @value = val; end; end; ::Marshal.dump(UsrMarshal.new(42), STDOUT); end; end"
          EnvUtil.invoke_ruby([], src, true)[0]
        end
    end

    def test_marshal
      v = ::Marshal.load(::Marshal.dump(UsrMarshal.new(42)))
      assert_instance_of(UsrMarshal, v)
      assert_equal(42, v.value)
    end

    def test_incompat
      assert_raise_with_message(ArgumentError, "dump format error") {::Marshal.load(old_dump)}
    end

    def test_compat
      out, err = EnvUtil.invoke_ruby(["-r-test-/marshal/usr", "-r-test-/marshal/compat", "-e", "::Marshal.dump(::Marshal.load(STDIN), STDOUT)"], old_dump, true, true)
      assert_equal(::Marshal.dump(UsrMarshal.new(42)), out)
      assert_equal("", err)
    end
  end
end
