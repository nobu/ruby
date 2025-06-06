# coding: us-ascii
# frozen_string_literal: true
require_relative 'utils'

if defined?(OpenSSL)

class OpenSSL::TestBN < OpenSSL::TestCase
  def setup
    super
    @e1 = OpenSSL::BN.new(999.to_s(16), 16) # OpenSSL::BN.new(str, 16) must be most stable
    @e2 = OpenSSL::BN.new("-" + 999.to_s(16), 16)
    @e3 = OpenSSL::BN.new((2**107-1).to_s(16), 16)
    @e4 = OpenSSL::BN.new("-" + (2**107-1).to_s(16), 16)
  end

  def test_new
    assert_raise(ArgumentError) { OpenSSL::BN.new }
    assert_raise(ArgumentError) { OpenSSL::BN.new(nil) }
    assert_raise(ArgumentError) { OpenSSL::BN.new(nil, 2) }

    assert_equal(@e1, OpenSSL::BN.new("999"))
    assert_equal(@e1, OpenSSL::BN.new("999", 10))
    assert_equal(@e1, OpenSSL::BN.new("\x03\xE7", 2))
    assert_equal(@e1, OpenSSL::BN.new("\x00\x00\x00\x02\x03\xE7", 0))
    assert_equal(@e2, OpenSSL::BN.new("-999"))
    assert_equal(@e2, OpenSSL::BN.new("-999", 10))
    assert_equal(@e2, OpenSSL::BN.new("\x00\x00\x00\x02\x83\xE7", 0))
    assert_equal(@e3, OpenSSL::BN.new((2**107-1).to_s))
    assert_equal(@e3, OpenSSL::BN.new((2**107-1).to_s, 10))
    assert_equal(@e3, OpenSSL::BN.new("\a\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF", 2))
    assert_equal(@e3, OpenSSL::BN.new("\x00\x00\x00\x0E\a\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF", 0))
    assert_equal(@e4, OpenSSL::BN.new("-" + (2**107-1).to_s))
    assert_equal(@e4, OpenSSL::BN.new("-" + (2**107-1).to_s, 10))
    assert_equal(@e4, OpenSSL::BN.new("\x00\x00\x00\x0E\x87\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF", 0))

    e1copy = OpenSSL::BN.new(@e1)
    assert_equal(@e1, e1copy)
    e1copy.clear_bit!(0) #=> 998
    assert_not_equal(@e1, e1copy)

    assert_equal(@e1, OpenSSL::BN.new(999))
    assert_equal(@e2, OpenSSL::BN.new(-999))
    assert_equal(@e3, OpenSSL::BN.new(2**107-1))
    assert_equal(@e4, OpenSSL::BN.new(-(2**107-1)))

    assert_equal(@e1, 999.to_bn)
    assert_equal(@e2, -999.to_bn)
    assert_equal(@e3, (2**107-1).to_bn)
    assert_equal(@e4, (-(2**107-1)).to_bn)
  end

  def test_to_str
    assert_equal("999", @e1.to_s(10))
    assert_equal("-999", @e2.to_s(10))
    assert_equal((2**107-1).to_s, @e3.to_s(10))
    assert_equal((-(2**107-1)).to_s, @e4.to_s(10))
    assert_equal("999", @e1.to_s)

    assert_equal("03E7", @e1.to_s(16))
    assert_equal("-03E7", @e2.to_s(16))
    assert_equal("07FFFFFFFFFFFFFFFFFFFFFFFFFF", @e3.to_s(16))
    assert_equal("-07FFFFFFFFFFFFFFFFFFFFFFFFFF", @e4.to_s(16))

    assert_equal("\x03\xe7", @e1.to_s(2))
    assert_equal("\x03\xe7", @e2.to_s(2))
    assert_equal("\x07\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff", @e3.to_s(2))
    assert_equal("\x07\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff", @e4.to_s(2))

    assert_equal("\x00\x00\x00\x02\x03\xe7", @e1.to_s(0))
    assert_equal("\x00\x00\x00\x02\x83\xe7", @e2.to_s(0))
    assert_equal("\x00\x00\x00\x0e\x07\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff", @e3.to_s(0))
    assert_equal("\x00\x00\x00\x0e\x87\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff", @e4.to_s(0))
  end

  def test_to_int
    assert_equal(999, @e1.to_i)
    assert_equal(-999, @e2.to_i)
    assert_equal(2**107-1, @e3.to_i)
    assert_equal(-(2**107-1), @e4.to_i)

    assert_equal(999, @e1.to_int)
  end

  def test_coerce
    assert_equal(["", "-999"], @e2.coerce(""))
    assert_equal([1000, -999], @e2.coerce(1000))
    assert_raise(TypeError) { @e2.coerce(Class.new.new) }
  end

  def test_zero_p
    assert_equal(true, 0.to_bn.zero?)
    assert_equal(false, 1.to_bn.zero?)
  end

  def test_one_p
    assert_equal(true, 1.to_bn.one?)
    assert_equal(false, 2.to_bn.one?)
  end

  def test_odd_p
    assert_equal(true, 1.to_bn.odd?)
    assert_equal(false, 2.to_bn.odd?)
  end

  def test_negative_p
    assert_equal(false, 0.to_bn.negative?)
    assert_equal(false, @e1.negative?)
    assert_equal(true, @e2.negative?)
  end

  def test_sqr
    assert_equal(1, 1.to_bn.sqr)
    assert_equal(100, 10.to_bn.sqr)
  end

  def test_four_ops
    assert_equal(3, 1.to_bn + 2)
    assert_equal(-1, 1.to_bn + -2)
    assert_equal(-1, 1.to_bn - 2)
    assert_equal(3, 1.to_bn - -2)
    assert_equal(2, 1.to_bn * 2)
    assert_equal(-2, 1.to_bn * -2)
    assert_equal([0, 1], 1.to_bn / 2)
    assert_equal([2, 0], 2.to_bn / 1)
    assert_raise(OpenSSL::BNError) { 1.to_bn / 0 }
  end

  def test_unary_plus_minus
    assert_equal(999, +@e1)
    assert_equal(-999, +@e2)
    assert_equal(-999, -@e1)
    assert_equal(+999, -@e2)

    # These methods create new BN instances due to BN mutability
    # Ensure that the instance isn't the same
    e1_plus = +@e1
    e1_minus = -@e1
    assert_equal(false, @e1.equal?(e1_plus))
    assert_equal(true, @e1 == e1_plus)
    assert_equal(false, @e1.equal?(e1_minus))
  end

  def test_abs
    assert_equal(@e1, @e2.abs)
    assert_equal(@e3, @e4.abs)
    assert_not_equal(@e2, @e2.abs)
    assert_not_equal(@e4, @e4.abs)
    assert_equal(false, @e2.abs.negative?)
    assert_equal(false, @e4.abs.negative?)
    assert_equal(true, (-@e1.abs).negative?)
    assert_equal(true, (-@e2.abs).negative?)
    assert_equal(true, (-@e3.abs).negative?)
    assert_equal(true, (-@e4.abs).negative?)
  end

  def test_mod
    assert_equal(1, 1.to_bn % 2)
    assert_equal(0, 2.to_bn % 1)
    assert_equal(-2, -2.to_bn % 7)
  end

  def test_exp
    assert_equal(1, 1.to_bn ** 5)
    assert_equal(32, 2.to_bn ** 5)
  end

  def test_gcd
    assert_equal(1, 7.to_bn.gcd(5))
    assert_equal(8, 24.to_bn.gcd(16))
  end

  def test_mod_sqr
    assert_equal(4, 3.to_bn.mod_sqr(5))
    assert_equal(0, 59.to_bn.mod_sqr(59))
  end

  def test_mod_sqrt
    assert_equal(4, 4.to_bn.mod_sqrt(5).mod_sqr(5))
    # One of 189484 or 326277 is returned as a square root of 2 (mod 515761).
    assert_equal(2, 2.to_bn.mod_sqrt(515761).mod_sqr(515761))
    assert_equal(0, 5.to_bn.mod_sqrt(5))
    assert_raise(OpenSSL::BNError) { 3.to_bn.mod_sqrt(5) }
  end

  def test_mod_inverse
    assert_equal(2, 3.to_bn.mod_inverse(5))
    assert_raise(OpenSSL::BNError) { 3.to_bn.mod_inverse(6) }
  end

  def test_mod_add
    assert_equal(1, 3.to_bn.mod_add(5, 7))
    assert_equal(2, 3.to_bn.mod_add(5, 3))
    assert_equal(5, 3.to_bn.mod_add(-5, 7))
  end

  def test_mod_sub
    assert_equal(1, 11.to_bn.mod_sub(3, 7))
    assert_equal(2, 11.to_bn.mod_sub(3, 3))
    assert_equal(5, 3.to_bn.mod_sub(5, 7))
  end

  def test_mod_mul
    assert_equal(1, 2.to_bn.mod_mul(4, 7))
    assert_equal(5, 2.to_bn.mod_mul(-1, 7))
  end

  def test_mod_exp
    assert_equal(1, 3.to_bn.mod_exp(2, 8))
    assert_equal(4, 2.to_bn.mod_exp(5, 7))
  end

  def test_bit_operations
    e = 0b10010010.to_bn
    assert_equal(0b10010011, e.set_bit!(0))
    assert_equal(0b10010011, e.set_bit!(1))
    assert_equal(0b1010010011, e.set_bit!(9))

    e = 0b10010010.to_bn
    assert_equal(0b10010010, e.clear_bit!(0))
    assert_equal(0b10010000, e.clear_bit!(1))

    e = 0b10010010.to_bn
    assert_equal(0b10010010, e.mask_bits!(8))
    assert_equal(0b10, e.mask_bits!(3))

    e = 0b10010010.to_bn
    assert_equal(false, e.bit_set?(0))
    assert_equal(true, e.bit_set?(1))
    assert_equal(false, e.bit_set?(1000))

    e = 0b10010010.to_bn
    assert_equal(0b1001001000, e << 2)
    assert_equal(0b10010010, e)
    assert_equal(0b1001001000, e.lshift!(2))
    assert_equal(0b1001001000, e)

    e = 0b10010010.to_bn
    assert_equal(0b100100, e >> 2)
    assert_equal(0b10010010, e)
    assert_equal(0b100100, e.rshift!(2))
    assert_equal(0b100100, e)
  end

  def test_random
    10.times {
      r1 = OpenSSL::BN.rand(8)
      assert_include(128..255, r1)
      r2 = OpenSSL::BN.rand(8, -1)
      assert_include(0..255, r2)
      r3 = OpenSSL::BN.rand(8, 1)
      assert_include(192..255, r3)
      r4 = OpenSSL::BN.rand(8, 1, true)
      assert_include(192..255, r4)
      assert_equal(true, r4.odd?)

      r5 = OpenSSL::BN.rand_range(256)
      assert_include(0..255, r5)
    }

    # Aliases
    assert_include(128..255, OpenSSL::BN.pseudo_rand(8))
    assert_include(0..255, OpenSSL::BN.pseudo_rand_range(256))
  end

  begin
    require "prime"

    def test_prime
      p1 = OpenSSL::BN.generate_prime(32)
      assert_include(0...2**32, p1)
      assert_equal(true, Prime.prime?(p1.to_i))
      p2 = OpenSSL::BN.generate_prime(32, true)
      assert_equal(true, Prime.prime?((p2.to_i - 1) / 2))
      p3 = OpenSSL::BN.generate_prime(32, false, 4)
      assert_equal(1, p3 % 4)
      p4 = OpenSSL::BN.generate_prime(32, false, 4, 3)
      assert_equal(3, p4 % 4)

      assert_equal(true, p1.prime?)
      assert_equal(true, p2.prime?)
      assert_equal(true, p3.prime?)
      assert_equal(true, p4.prime?)
      assert_equal(true, @e3.prime?)
      assert_equal(true, @e3.prime_fasttest?)
    end
  rescue LoadError
    # prime is the bundled gems at Ruby 3.1
  end

  def test_num_bits_bytes
    assert_equal(10, @e1.num_bits)
    assert_equal(2, @e1.num_bytes)
    assert_equal(107, @e3.num_bits)
    assert_equal(14, @e3.num_bytes)
    assert_equal(0, 0.to_bn.num_bits)
    assert_equal(0, 0.to_bn.num_bytes)
    assert_equal(9, -256.to_bn.num_bits)
    assert_equal(2, -256.to_bn.num_bytes)
  end

  def test_comparison
    assert_equal(false, @e1 == nil)
    assert_equal(false, @e1 == -999)
    assert_equal(true, @e1 == 999)
    assert_equal(true, @e1 == 999.to_bn)
    assert_equal(false, @e1.eql?(nil))
    assert_equal(false, @e1.eql?(999))
    assert_equal(true, @e1.eql?(999.to_bn))
    assert_equal(@e1.hash, 999.to_bn.hash)
    assert_not_equal(@e1.hash, @e3.hash)
    assert_equal(0, @e1.cmp(999))
    assert_equal(1, @e1.cmp(-999))
    assert_equal(0, @e1.ucmp(999))
    assert_equal(0, @e1.ucmp(-999))
    assert_instance_of(String, @e1.hash.to_s)
  end

  def test_argument_error
    bug15760 = '[ruby-core:92231] [Bug #15760]'
    assert_raise(ArgumentError, bug15760) { OpenSSL::BN.new(nil, 2) }
  end

  def test_get_flags_and_set_flags
    return if aws_lc? # AWS-LC does not support BN::CONSTTIME.

    e = OpenSSL::BN.new(999)

    assert_equal(0, e.get_flags(OpenSSL::BN::CONSTTIME))

    e.set_flags(OpenSSL::BN::CONSTTIME)
    assert_equal(OpenSSL::BN::CONSTTIME, e.get_flags(OpenSSL::BN::CONSTTIME))

    b = OpenSSL::BN.new(2)
    m = OpenSSL::BN.new(99)
    assert_equal("17", b.mod_exp(e, m).to_s)

    # mod_exp fails when m is even and any argument has CONSTTIME flag
    m = OpenSSL::BN.new(98)
    assert_raise(OpenSSL::BNError) do
      b.mod_exp(e, m)
    end

    # It looks like flags cannot be removed once enabled
    e.set_flags(0)
    assert_equal(4, e.get_flags(OpenSSL::BN::CONSTTIME))
  end

  if defined?(Ractor) && respond_to?(:ractor)
    unless Ractor.method_defined?(:value) # Ruby 3.4 or earlier
      using Module.new {
        refine Ractor do
          alias value take
        end
      }
    end

    ractor
    def test_ractor
      assert_equal(@e1, Ractor.new { OpenSSL::BN.new("999") }.value)
      assert_equal(@e3, Ractor.new { OpenSSL::BN.new("\a\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF", 2) }.value)
      assert_equal("999", Ractor.new(@e1) { |e1| e1.to_s }.value)
      assert_equal("07FFFFFFFFFFFFFFFFFFFFFFFFFF", Ractor.new(@e3) { |e3| e3.to_s(16) }.value)
      assert_equal(2**107-1, Ractor.new(@e3) { _1.to_i }.value)
      assert_equal([1000, -999], Ractor.new(@e2) { _1.coerce(1000) }.value)
      assert_equal(false, Ractor.new  { 1.to_bn.zero? }.value)
      assert_equal(true, Ractor.new { 1.to_bn.one? }.value)
      assert_equal(true, Ractor.new(@e2) { _1.negative? }.value)
      assert_equal("-03E7", Ractor.new(@e2) { _1.to_s(16) }.value)
      assert_equal(2**107-1, Ractor.new(@e3) { _1.to_i }.value)
      assert_equal([1000, -999], Ractor.new(@e2) { _1.coerce(1000) }.value)
      assert_equal(true, Ractor.new { 0.to_bn.zero? }.value)
      assert_equal(true, Ractor.new { 1.to_bn.one? }.value )
      assert_equal(false,Ractor.new { 2.to_bn.odd? }.value)
      assert_equal(true, Ractor.new(@e2) { _1.negative? }.value)
      assert_include(128..255, Ractor.new { OpenSSL::BN.rand(8)}.value)
      assert_include(0...2**32, Ractor.new { OpenSSL::BN.generate_prime(32) }.value)
      if !aws_lc? # AWS-LC does not support BN::CONSTTIME.
        assert_equal(0, Ractor.new { OpenSSL::BN.new(999).get_flags(OpenSSL::BN::CONSTTIME) }.value)
      end
      # test if shareable when frozen
      assert Ractor.shareable?(@e1.freeze)
    end
  end
end

end
