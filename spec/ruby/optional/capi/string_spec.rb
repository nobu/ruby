# encoding: utf-8
# frozen_string_literal: false
require_relative 'spec_helper'
require_relative '../../shared/string/times'

load_extension('string')

class CApiStringSpecs
  class ValidTostrTest
    def to_str
      "ruby"
    end
  end

  class InvalidTostrTest
    def to_str
      []
    end
  end

  class ToSOrInspect
    def to_s
      'A string'
    end

    def inspect
      'A different string'
    end
  end
end

describe :rb_str_new2, shared: true do
  it "returns a new string object calling strlen on the passed C string" do
    # Hardcoded to pass const char * = "hello\0invisible"
    @s.send(@method, "hello\0not used").should == "hello"
  end

  it "encodes the string with ASCII_8BIT" do
    @s.send(@method, "hello").encoding.should == Encoding::BINARY
  end
end

describe "C-API String function" do
  before :each do
    @s = CApiStringSpecs.new
  end

  [Encoding::BINARY, Encoding::UTF_8].each do |enc|
    describe "rb_str_set_len on a #{enc.name} String" do
      before :each do
        @str = "abcdefghij".dup.force_encoding(enc)
        # Make sure to unshare the string
        @s.rb_str_modify(@str)
      end

      it "reduces the size of the string" do
        @s.rb_str_set_len(@str, 5).should == "abcde"
      end

      it "inserts a NULL byte at the length" do
        @s.rb_str_set_len(@str, 5).should == "abcde"
        @s.rb_str_set_len(@str, 8).should == "abcde\x00gh"
      end

      it "updates the byte size" do
        @s.rb_str_set_len(@str, 4)
        @str.bytesize.should == 4
        @str.should == "abcd"
      end

      it "invalidates the character size" do
        @str.size.should == 10
        @s.rb_str_set_len(@str, 4)
        @str.size.should == 4
        @str.should == "abcd"
      end

      it "invalidates the code range" do
        @s.rb_str_set_len(@str, 4)
        @str.should.ascii_only?
      end

      it "updates the string's attributes visible in C code" do
        @s.rb_str_set_len_RSTRING_LEN(@str, 4).should == 4
      end

      it "can reveal characters written from C with RSTRING_PTR" do
        @s.rb_str_set_len(@str, 1)
        @str.should == "a"

        @s.RSTRING_PTR_set(@str, 1, 'B'.ord)
        @s.RSTRING_PTR_set(@str, 2, 'C'.ord)
        @s.rb_str_set_len(@str, 3)

        @str.bytesize.should == 3
        @str.should == "aBC"
      end
    end
  end

  describe "rb_str_set_len on a UTF-16 String" do
    before :each do
      @str = "abcdefghij".dup.force_encoding(Encoding::UTF_16BE)
      # Make sure to unshare the string
      @s.rb_str_modify(@str)
    end

    it "inserts two NULL bytes at the length" do
      @s.rb_str_set_len(@str, 4).b.should == "abcd".b
      @s.rb_str_set_len(@str, 8).b.should == "abcd\x00\x00gh".b
    end
  end

  describe "rb_str_set_len on a UTF-32 String" do
    before :each do
      @str = "abcdefghijkl".dup.force_encoding(Encoding::UTF_32BE)
      # Make sure to unshare the string
      @s.rb_str_modify(@str)
    end

    it "inserts four NULL bytes at the length" do
      @s.rb_str_set_len(@str, 4).b.should == "abcd".b
      @s.rb_str_set_len(@str, 12).b.should == "abcd\x00\x00\x00\x00ijkl".b
    end
  end

  describe "rb_str_buf_new" do
    it "returns the equivalent of an empty string" do
      buf = @s.rb_str_buf_new(10, nil)
      buf.should == ""
      buf.bytesize.should == 0
      buf.size.should == 0
      @s.RSTRING_LEN(buf).should == 0
    end

    it "returns a string with the given capacity" do
      buf = @s.rb_str_buf_new(256, nil)
      @s.rb_str_capacity(buf).should >= 256
    end

    it "returns a string that can be appended to" do
      str = @s.rb_str_buf_new(10, "defg")
      str << "abcde"
      str.should == "abcde"
    end

    it "returns a string that can be concatenated to another string" do
      str = @s.rb_str_buf_new(10, "defg")
      ("abcde" + str).should == "abcde"
    end

    it "returns a string whose bytes can be accessed by RSTRING_PTR" do
      str = @s.rb_str_buf_new(10, "abcdefghi")
      @s.rb_str_new(str, 10).should == "abcdefghi\x00"
    end

    it "returns a string that can be modified by rb_str_set_len" do
      str = @s.rb_str_buf_new(10, "abcdef")
      @s.rb_str_set_len(str, 4)
      str.should == "abcd"

      @s.rb_str_set_len(str, 8)
      str[0, 6].should == "abcd\x00f"
      @s.RSTRING_LEN(str).should == 8
    end

    it "can be used as a general buffer and reveal characters with rb_str_set_len" do
      str = @s.rb_str_buf_new(10, "abcdef")

      @s.RSTRING_PTR_set(str, 0, 195)
      @s.RSTRING_PTR_set(str, 1, 169)
      @s.rb_str_set_len(str, 2)

      str.force_encoding(Encoding::UTF_8)
      str.bytesize.should == 2
      str.size.should == 1
      str.should == "é"
    end
  end

  describe "rb_str_buf_new2" do
    it "returns a new string object calling strlen on the passed C string" do
      # Hardcoded to pass const char * = "hello\0invisible"
      @s.rb_str_buf_new2.should == "hello"
    end
  end

  describe "rb_str_tmp_new" do
    it "returns a hidden string (RBasic->klass is NULL)" do
      @s.rb_str_tmp_new_klass(4).should == false
    end

    it "returns a new String object filled with \\0 bytes" do
      s = @s.rb_str_tmp_new(4)
      s.encoding.should == Encoding::BINARY
      s.bytesize.should == 4
      s.size.should == 4
      s.should == "\x00\x00\x00\x00"
    end
  end

  describe "rb_str_new" do
    it "creates a new String with BINARY Encoding" do
      @s.rb_str_new("", 0).encoding.should == Encoding::BINARY
    end

    it "returns a new string object from a char buffer of len characters" do
      @s.rb_str_new("hello", 3).should == "hel"
    end

    it "returns an empty string if len is 0" do
      @s.rb_str_new("hello", 0).should == ""
    end

    it "copy length bytes and does not stop at the first \\0 byte" do
      @s.rb_str_new("he\x00llo", 6).should == "he\x00llo"
      @s.rb_str_new_native("he\x00llo", 6).should == "he\x00llo"
    end

    it "returns a string from an offset char buffer" do
      @s.rb_str_new_offset("hello", 1, 3).should == "ell"
    end
  end

  describe "rb_str_new2" do
    it_behaves_like :rb_str_new2, :rb_str_new2
  end

  describe "rb_str_new_cstr" do
    it_behaves_like :rb_str_new2, :rb_str_new_cstr
  end

  describe "rb_usascii_str_new" do
    it "creates a new String with US-ASCII Encoding from a char buffer of len characters" do
      str = "abc".dup.force_encoding("us-ascii")
      result = @s.rb_usascii_str_new("abcdef", 3)
      result.should == str
      result.encoding.should == Encoding::US_ASCII
    end
  end

  describe "rb_usascii_str_new_lit" do
    it "returns a US-ASCII string of the correct characters" do
      str = @s.rb_usascii_str_new_lit
      str.should == "nokogiri"
      str.encoding.should == Encoding::US_ASCII
    end

    it "returns US-ASCII string for non-US-ASCII string literal" do
      str = @s.rb_usascii_str_new_lit_non_ascii
      str.should == "r\xC3\xA9sum\xC3\xA9".dup.force_encoding(Encoding::US_ASCII)
      str.encoding.should == Encoding::US_ASCII
    end
  end

  describe "rb_usascii_str_new_cstr" do
    it "creates a new String with US-ASCII Encoding" do
      str = "abc".dup.force_encoding("us-ascii")
      result = @s.rb_usascii_str_new_cstr("abc")
      result.should == str
      result.encoding.should == Encoding::US_ASCII
    end
  end

  describe "rb_str_encode" do
    it "returns a String in the destination encoding" do
      result = @s.rb_str_encode("abc", Encoding::ISO_8859_1, 0, nil)
      result.encoding.should == Encoding::ISO_8859_1
    end

    it "transcodes the String" do
      result = @s.rb_str_encode("ありがとう", "euc-jp", 0, nil)
      euc_jp = [0xa4, 0xa2, 0xa4, 0xea, 0xa4, 0xac, 0xa4, 0xc8, 0xa4, 0xa6].pack('C*').force_encoding("euc-jp")
      result.should == euc_jp
      result.encoding.should == Encoding::EUC_JP
    end

    it "returns a dup of the original String" do
      a = "abc"
      b = @s.rb_str_encode("abc", "us-ascii", 0, nil)
      a.should_not equal(b)
    end

    it "returns a duplicate of the original when the encoding doesn't change" do
      a = "abc"
      b = @s.rb_str_encode("abc", Encoding::UTF_8, 0, nil)
      a.should_not equal(b)
    end

    it "accepts encoding flags" do
      xFF = [0xFF].pack('C').force_encoding('utf-8')
      result = @s.rb_str_encode("a#{xFF}c", "us-ascii",
                                Encoding::Converter::INVALID_REPLACE, nil)
      result.should == "a?c"
      result.encoding.should == Encoding::US_ASCII
    end

    it "accepts an encoding options Hash specifying replacement String" do
      # Yeah, MRI aborts with rb_bug() if the options Hash is not frozen
      options = { replace: "b" }.freeze
      xFF = [0xFF].pack('C').force_encoding('utf-8')
      result = @s.rb_str_encode("a#{xFF}c", "us-ascii",
                                Encoding::Converter::INVALID_REPLACE,
                                options)
      result.should == "abc"
      result.encoding.should == Encoding::US_ASCII
    end
  end

  describe "rb_str_new3" do
    it "returns a copy of the string" do
      str1 = "hi"
      str2 = @s.rb_str_new3 str1
      str1.should == str2
      str1.should_not equal str2
    end
  end

  describe "rb_str_new4" do
    it "returns the original string if it is already frozen" do
      str1 = "hi"
      str1.freeze
      str2 = @s.rb_str_new4 str1
      str1.should == str2
      str1.should equal(str2)
      str1.should.frozen?
      str2.should.frozen?
    end

    it "returns a frozen copy of the string" do
      str1 = "hi"
      str2 = @s.rb_str_new4 str1
      str1.should == str2
      str1.should_not equal(str2)
      str2.should.frozen?
    end
  end

  describe "rb_str_dup" do
    it "returns a copy of the string" do
      str1 = "hi"
      str2 = @s.rb_str_dup str1
      str1.should == str2
      str1.should_not equal str2
    end
  end

  describe "rb_str_new5" do
    it "returns a new string with the same class as the passed string" do
      string_class = Class.new(String)
      template_string = string_class.new("hello world")
      new_string = @s.rb_str_new5(template_string, "hello world", 11)

      new_string.should == "hello world"
      new_string.class.should == string_class
    end
  end

  describe "rb_str_append" do
    it "appends a string to another string" do
      @s.rb_str_append("Hello", " Goodbye").should == "Hello Goodbye"
    end

    it "raises a TypeError trying to append non-String-like object" do
      -> { @s.rb_str_append("Hello", 32323)}.should raise_error(TypeError)
    end

    it "changes Encoding if a string is appended to an empty string" do
      string = "パスタ".encode(Encoding::ISO_2022_JP)
      @s.rb_str_append("", string).encoding.should == Encoding::ISO_2022_JP
    end
  end

  describe "rb_str_plus" do
    it "returns a new string from concatenating two other strings" do
      @s.rb_str_plus("Hello", " Goodbye").should == "Hello Goodbye"
    end
  end

  describe "rb_str_times" do
    it_behaves_like :string_times, :rb_str_times, -> str, times { @s.rb_str_times(str, times) }
  end

  describe "rb_str_buf_append" do
    it "concatenates a string to another string" do
      str = "Your house "
      @s.rb_str_buf_append(str, "is on fire?").should.equal?(str)
      str.should == "Your house is on fire?"
    end
  end

  describe "rb_str_buf_cat" do
    it "concatenates a C string to a ruby string" do
      @s.rb_str_buf_cat("Your house is on fire").should == "Your house is on fire?"
    end
  end

  describe "rb_str_cat" do
    it "concatenates a C string to ruby string" do
      @s.rb_str_cat("Your house is on fire").should == "Your house is on fire?"
    end
  end

  describe "rb_str_cat2" do
    it "concatenates a C string to a ruby string" do
      @s.rb_str_cat2("Your house is on fire").should == "Your house is on fire?"
    end
  end

  describe "rb_str_cat_cstr" do
    it "concatenates a C string literal to a ruby string" do
      @s.rb_str_cat_cstr_constant("Your house is on fire").should == "Your house is on fire?"
    end

    it "concatenates a variable C string to a ruby string" do
      @s.rb_str_cat_cstr("Your house is on fire", "?").should == "Your house is on fire?"
    end
  end

  describe "rb_enc_str_buf_cat" do
    it "concatenates a C string literal to a ruby string with the given encoding" do
      input = "hello ".dup.force_encoding(Encoding::US_ASCII)
      result = @s.rb_enc_str_buf_cat(input, "résumé", Encoding::UTF_8)
      result.should == "hello résumé"
      result.encoding.should == Encoding::UTF_8
      result.object_id.should == input.object_id
    end
  end

  describe "rb_str_cmp" do
    it "returns 0 if two strings are identical" do
      @s.rb_str_cmp("ppp", "ppp").should == 0
    end

    it "returns -1 if the first string is shorter than the second" do
      @s.rb_str_cmp("xxx", "xxxx").should == -1
    end

    it "returns -1 if the first string is lexically less than the second" do
      @s.rb_str_cmp("xxx", "yyy").should == -1
    end

    it "returns 1 if the first string is longer than the second" do
      @s.rb_str_cmp("xxxx", "xxx").should == 1
    end

    it "returns 1 if the first string is lexically greater than the second" do
      @s.rb_str_cmp("yyy", "xxx").should == 1
    end
  end

  describe "rb_str_strlen" do
    it 'returns 0 as the length of an empty string' do
      @s.rb_str_strlen('').should == 0
    end

    it 'returns the number of characters in a string' do
      @s.rb_str_strlen('hello').should == 5
    end

    it 'returns the number of characters in a string with multi-byte characters' do
      @s.rb_str_strlen('こんにちは').should == 5
    end
  end

  describe "rb_str_split" do
    it "splits strings over a splitter" do
      @s.rb_str_split("Hello,Goodbye").should == ["Hello", "Goodbye"]
    end
  end

  describe "rb_str2inum" do
    it "converts a string to a number given a base" do
      @s.rb_str2inum("10", 10).should == 10
      @s.rb_str2inum("A", 16).should == 10
    end
  end

  describe "rb_cstr2inum" do
    it "converts a C string to a Fixnum given a base" do
      @s.rb_cstr2inum("10", 10).should == 10
      @s.rb_cstr2inum("10", 16).should == 16
    end

    it "converts a C string to a Bignum given a base" do
      @s.rb_cstr2inum(bignum_value.to_s, 10).should == bignum_value
    end

    it "converts a C string to a Fixnum non-strictly if base is not 0" do
      @s.rb_cstr2inum("1234a", 10).should == 1234
    end

    it "converts a C string to a Fixnum strictly if base is 0" do
      -> { @s.rb_cstr2inum("1234a", 0) }.should raise_error(ArgumentError)
    end
  end

  describe "rb_cstr_to_inum" do
    it "converts a C string to a Fixnum given a base" do
      @s.rb_cstr_to_inum("1234", 10, true).should == 1234
    end

    it "converts a C string to a Bignum given a base" do
      @s.rb_cstr_to_inum(bignum_value.to_s, 10, true).should == bignum_value
    end

    it "converts a C string to a Fixnum non-strictly" do
      @s.rb_cstr_to_inum("1234a", 10, false).should == 1234
    end

    it "converts a C string to a Fixnum strictly" do
      -> { @s.rb_cstr_to_inum("1234a", 10, true) }.should raise_error(ArgumentError)
    end
  end

  describe "rb_str_subseq" do
    it "returns a byte-indexed substring" do
      str = "\x00\x01\x02\x03\x04".dup.force_encoding("binary")
      @s.rb_str_subseq(str, 1, 2).should == "\x01\x02".dup.force_encoding("binary")
    end
  end

  describe "rb_str_substr" do
    it "returns a substring" do
      "hello".length.times do |time|
        @s.rb_str_substr("hello", 0, time + 1).should == "hello"[0..time]
      end
    end
  end

  describe "rb_str_to_str" do
    it "calls #to_str to coerce the value to a String" do
      @s.rb_str_to_str("foo").should == "foo"
      @s.rb_str_to_str(CApiStringSpecs::ValidTostrTest.new).should == "ruby"
    end

    it "raises a TypeError if coercion fails" do
      -> { @s.rb_str_to_str(0) }.should raise_error(TypeError)
      -> { @s.rb_str_to_str(CApiStringSpecs::InvalidTostrTest.new) }.should raise_error(TypeError)
    end
  end

  describe "RSTRING_PTR" do
    it "returns a pointer to the string's contents" do
      str = "abc"
      chars = []
      @s.RSTRING_PTR_iterate(str) do |c|
        chars << c
      end
      chars.should == [97, 98, 99]
    end

    it "allows changing the characters in the string" do
      str = "abc"
      @s.RSTRING_PTR_assign(str, 'A'.ord)
      str.should == "AAA"
    end

    it "reflects changes after a rb_funcall" do
      lamb = proc { |s| s.replace "NEW CONTENT" }

      str = "beforebefore"

      ret = @s.RSTRING_PTR_after_funcall(str, lamb)

      str.should == "NEW CONTENT"
      ret.should == str
    end

    it "reflects changes from native memory and from String#setbyte in bounds" do
      str = "abc"
      from_rstring_ptr = @s.RSTRING_PTR_after_yield(str) { str.setbyte(1, 'B'.ord) }
      from_rstring_ptr.should == "1B2"
      str.should == "1B2"
    end

    it "returns a pointer to the contents of encoded pointer-sized string" do
      s = "70パク".
        encode(Encoding::UTF_16LE).
        force_encoding(Encoding::UTF_16LE).
        encode(Encoding::UTF_8)

      chars = []
      @s.RSTRING_PTR_iterate(s) do |c|
        chars << c
      end
      chars.should == [55, 48, 227, 131, 145, 227, 130, 175]
    end

    it "returns a pointer which can be cast and used as another type" do
      s = "70パク".
        encode(Encoding::UTF_16LE).
        force_encoding(Encoding::UTF_16LE).
        encode(Encoding::UTF_8)

      ints = []
      @s.RSTRING_PTR_iterate_uint32(s) do |i|
        ints << i
      end
      ints.should == s.unpack('LL')
    end

    it "allows a short memcpy to the string which may be converted to a single write operation by the compiler" do
      str = "        "
      @s.RSTRING_PTR_short_memcpy(str).should == "Infinity"
    end

    it "allows read() to update the string contents" do
      filename = fixture(__FILE__, "read.txt")
      str = ""
      capacities = @s.RSTRING_PTR_read(str, filename)
      capacities[0].should >= 30
      capacities[1].should >= 53
      capacities[0].should < capacities[1]
      str.should == "fixture file contents to test read() with RSTRING_PTR"
    end

    it "terminates the string with at least (encoding min length) \\0 bytes" do
      @s.RSTRING_PTR_null_terminate("abc", 1).should == "\x00"
      @s.RSTRING_PTR_null_terminate("abc".encode("UTF-16BE"), 2).should == "\x00\x00"
      @s.RSTRING_PTR_null_terminate("abc".encode("UTF-32BE"), 4).should == "\x00\x00\x00\x00"
    end
  end

  describe "RSTRING_LEN" do
    it "returns the size of the string" do
      @s.RSTRING_LEN("gumdrops").should == 8
    end
  end

  describe "RSTRING_LENINT" do
    it "returns the size of a string" do
      @s.RSTRING_LENINT("silly").should == 5
    end
  end

  describe :string_value_macro, shared: true do
    before :each do
      @s = CApiStringSpecs.new
    end

    it "does not call #to_str on a String" do
      str = "genuine"
      str.should_not_receive(:to_str)
      @s.send(@method, str)
    end

    it "does not call #to_s on a String" do
      str = "genuine"
      str.should_not_receive(:to_str)
      @s.send(@method, str)
    end

    it "calls #to_str on non-String objects" do
      str = mock("fake")
      str.should_receive(:to_str).and_return("wannabe")
      @s.send(@method, str).should == "wannabe"
    end

    it "does not call #to_s on non-String objects" do
      str = mock("fake")
      str.should_not_receive(:to_s)
      -> { @s.send(@method, str) }.should raise_error(TypeError)
    end
  end

  describe "StringValue" do
    it_behaves_like :string_value_macro, :StringValue
  end

  describe "SafeStringValue" do
  end

  describe "rb_str_modify" do
    it "raises an error if the string is frozen" do
      -> { @s.rb_str_modify("frozen".freeze) }.should raise_error(FrozenError)
    end
  end

  describe "rb_str_modify_expand" do
    it "grows the capacity to bytesize + expand, not changing the bytesize" do
      str = @s.rb_str_buf_new(256, "abcd")
      @s.rb_str_capacity(str).should >= 256

      @s.rb_str_set_len(str, 3)
      str.bytesize.should == 3
      @s.RSTRING_LEN(str).should == 3
      @s.rb_str_capacity(str).should >= 256

      @s.rb_str_modify_expand(str, 4)
      str.bytesize.should == 3
      @s.RSTRING_LEN(str).should == 3
      @s.rb_str_capacity(str).should >= 7

      @s.rb_str_modify_expand(str, 1024)
      str.bytesize.should == 3
      @s.RSTRING_LEN(str).should == 3
      @s.rb_str_capacity(str).should >= 1027

      @s.rb_str_modify_expand(str, 1)
      str.bytesize.should == 3
      @s.RSTRING_LEN(str).should == 3
      @s.rb_str_capacity(str).should >= 4
    end

    it "raises an error if the string is frozen" do
      -> { @s.rb_str_modify_expand("frozen".freeze, 10) }.should raise_error(FrozenError)
    end
  end

  describe "rb_str_resize" do
    it "reduces the size of the string" do
      str = @s.rb_str_resize("test", 2)
      str.size.should == 2
      str.bytesize.should == 2
      @s.RSTRING_LEN(str).should == 2
      str.should == "te"
    end

    it "updates the string's attributes visible in C code" do
      @s.rb_str_resize_RSTRING_LEN("test", 2).should == 2
    end

    it "copies the existing bytes" do
      str = "t"
      @s.rb_str_resize_copy(str).should == "test"
    end

    it "increases the size of the string" do
      expected = "test".dup.force_encoding("US-ASCII")
      str = @s.rb_str_resize(expected.dup, 12)
      str.size.should == 12
      str.bytesize.should == 12
      @s.RSTRING_LEN(str).should == 12
      str[0, 4].should == expected
    end
  end

  describe "rb_str_inspect" do
    it "returns the equivalent of calling #inspect on the String" do
      @s.rb_str_inspect("value").should == %["value"]
    end
  end

  describe "rb_str_intern" do
    it "returns a symbol created from the string" do
      @s.rb_str_intern("symbol").should == :symbol
    end

    it "returns a symbol even if passed an empty string" do
      @s.rb_str_intern("").should == "".to_sym
    end

    it "returns a symbol even if the passed string contains NULL characters" do
      @s.rb_str_intern("no\0no").should == "no\0no".to_sym
    end
  end

  describe "rb_str_freeze" do
    it "freezes the string" do
      s = ""
      @s.rb_str_freeze(s).should == s
      s.frozen?.should be_true
    end
  end

  describe "rb_str_hash" do
    it "hashes the string into a number" do
      s = "hello"
      @s.rb_str_hash(s).should be_kind_of(Integer)
    end
  end

  describe "rb_str_update" do
    it "splices the replacement string into the original at the given location" do
      @s.rb_str_update("hello", 2, 3, "wuh").should == "hewuh"
    end
  end
end

describe "rb_str_free" do
  # This spec only really exists to make sure the symbol
  # is available. There is no guarantee this even does
  # anything at all
  it "indicates data for a string might be freed" do
    @s.rb_str_free("xyz").should be_nil
  end
end

describe :rb_external_str_new, shared: true do
  it "returns a String in the default external encoding" do
    Encoding.default_external = "UTF-8"
    @s.send(@method, "abc").encoding.should == Encoding::UTF_8
  end

  it "returns a binary encoded string if any non-ascii bytes are present and default external is US-ASCII" do
    Encoding.default_external = "US-ASCII"
    x80 = [0x80].pack('C')
    @s.send(@method, "#{x80}abc").encoding.should == Encoding::BINARY
  end
end

describe "C-API String function" do
  before :each do
    @s = CApiStringSpecs.new
    @external = Encoding.default_external
    @internal = Encoding.default_internal
  end

  after :each do
    Encoding.default_external = @external
    Encoding.default_internal = @internal
  end

  describe "rb_str_length" do
    it "returns the string's length" do
      @s.rb_str_length("dewdrops").should == 8
    end

    it "counts characters in multi byte encodings" do
      @s.rb_str_length("düwdrops").should == 8
    end
  end

  describe "rb_str_equal" do
    it "compares two same strings" do
      s = "hello"
      @s.rb_str_equal(s, "hello").should be_true
    end

    it "compares two different strings" do
      s = "hello"
      @s.rb_str_equal(s, "hella").should be_false
    end
  end

  describe "rb_external_str_new" do
    it_behaves_like :rb_external_str_new, :rb_external_str_new
  end

  describe "rb_external_str_new_cstr" do
    it_behaves_like :rb_external_str_new, :rb_external_str_new_cstr
  end

  describe "rb_external_str_new_with_enc" do
    it "returns a String in the specified encoding" do
      s = @s.rb_external_str_new_with_enc("abc", 3, Encoding::UTF_8)
      s.encoding.should == Encoding::UTF_8
    end

    it "returns a binary encoded String if any non-ascii bytes are present and the specified encoding is US-ASCII" do
      x80 = [0x80].pack('C')
      s = @s.rb_external_str_new_with_enc("#{x80}abc", 4, Encoding::US_ASCII)
      s.encoding.should == Encoding::BINARY
    end


#     it "transcodes a String to Encoding.default_internal if it is set" do
#       Encoding.default_internal = Encoding::EUC_JP
#
#  -      a = "\xE3\x81\x82\xe3\x82\x8c".dup.force_encoding("utf-8")
#  +      a = [0xE3, 0x81, 0x82, 0xe3, 0x82, 0x8c].pack('C6').force_encoding("utf-8")
#         s = @s.rb_external_str_new_with_enc(a, a.bytesize, Encoding::UTF_8)
#  -
#  -      s.should == "\xA4\xA2\xA4\xEC".dup.force_encoding("euc-jp")
#  +      x = [0xA4, 0xA2, 0xA4, 0xEC].pack('C4')#.force_encoding('binary')
#  +      s.should == x
#         s.encoding.should equal(Encoding::EUC_JP)
#     end

    it "transcodes a String to Encoding.default_internal if it is set" do
      Encoding.default_internal = Encoding::EUC_JP

      a = [0xE3, 0x81, 0x82, 0xe3, 0x82, 0x8c].pack('C6').force_encoding("utf-8")
      s = @s.rb_external_str_new_with_enc(a, a.bytesize, Encoding::UTF_8)
      x = [0xA4, 0xA2, 0xA4, 0xEC].pack('C4').force_encoding('euc-jp')
      s.should == x
      s.encoding.should equal(Encoding::EUC_JP)
    end
  end

  describe "rb_locale_str_new" do
    it "returns a String with 'locale' encoding" do
      s = @s.rb_locale_str_new("abc", 3)
      s.should == "abc".dup.force_encoding(Encoding.find("locale"))
      s.encoding.should equal(Encoding.find("locale"))
    end
  end

  describe "rb_locale_str_new_cstr" do
    it "returns a String with 'locale' encoding" do
      s = @s.rb_locale_str_new_cstr("abc")
      s.should == "abc".dup.force_encoding(Encoding.find("locale"))
      s.encoding.should equal(Encoding.find("locale"))
    end
  end

  describe "rb_str_conv_enc" do
    it "returns the original String when to encoding is not specified" do
      a = "abc".dup.force_encoding("us-ascii")
      @s.rb_str_conv_enc(a, Encoding::US_ASCII, nil).should equal(a)
    end

    it "returns the original String if a transcoding error occurs" do
      a = [0xEE].pack('C').force_encoding(Encoding::UTF_8)
      @s.rb_str_conv_enc(a, Encoding::UTF_8, Encoding::EUC_JP).should.equal?(a)
      a.encoding.should == Encoding::UTF_8

      a = "\x80".b
      @s.rb_str_conv_enc(a, Encoding::BINARY, Encoding::UTF_8).should.equal?(a)
      a.encoding.should == Encoding::BINARY
    end

    it "returns a transcoded String" do
      a = "\xE3\x81\x82\xE3\x82\x8C".dup.force_encoding(Encoding::UTF_8)
      result = @s.rb_str_conv_enc(a, Encoding::UTF_8, Encoding::EUC_JP)
      result.should == [0xA4, 0xA2, 0xA4, 0xEC].pack('C4').force_encoding(Encoding::EUC_JP)
      result.encoding.should == Encoding::EUC_JP
    end

    describe "when the String encoding is equal to the destination encoding" do
      it "returns the original String" do
        a = "abc".dup.force_encoding("us-ascii")
        @s.rb_str_conv_enc(a, Encoding::US_ASCII, Encoding::US_ASCII).should equal(a)
      end

      it "returns the original String if the destination encoding is ASCII compatible and the String has no high bits set" do
        a = "abc".encode("us-ascii")
        @s.rb_str_conv_enc(a, Encoding::UTF_8, Encoding::US_ASCII).should equal(a)
      end

      it "returns the origin String if the destination encoding is BINARY" do
        a = "abc".dup.force_encoding("binary")
        @s.rb_str_conv_enc(a, Encoding::US_ASCII, Encoding::BINARY).should equal(a)
      end
    end
  end

  describe "rb_str_conv_enc_opts" do
    it "returns the original String when to encoding is not specified" do
      a = "abc".dup.force_encoding("us-ascii")
      @s.rb_str_conv_enc_opts(a, Encoding::US_ASCII, nil, 0, nil).should equal(a)
    end

    it "returns the original String if a transcoding error occurs" do
      a = [0xEE].pack('C').force_encoding("utf-8")
      @s.rb_str_conv_enc_opts(a, Encoding::UTF_8,
                              Encoding::EUC_JP, 0, nil).should equal(a)
    end

    it "returns a transcoded String" do
      a = "\xE3\x81\x82\xE3\x82\x8C".dup.force_encoding("utf-8")
      result = @s.rb_str_conv_enc_opts(a, Encoding::UTF_8, Encoding::EUC_JP, 0, nil)
      x = [0xA4, 0xA2, 0xA4, 0xEC].pack('C4').force_encoding('utf-8')
      result.should == x.force_encoding("euc-jp")
      result.encoding.should equal(Encoding::EUC_JP)
    end

    describe "when the String encoding is equal to the destination encoding" do
      it "returns the original String" do
        a = "abc".dup.force_encoding("us-ascii")
        @s.rb_str_conv_enc_opts(a, Encoding::US_ASCII,
                                Encoding::US_ASCII, 0, nil).should equal(a)
      end

      it "returns the original String if the destination encoding is ASCII compatible and the String has no high bits set" do
        a = "abc".encode("us-ascii")
        @s.rb_str_conv_enc_opts(a, Encoding::UTF_8,
                                Encoding::US_ASCII, 0, nil).should equal(a)
      end

      it "returns the origin String if the destination encoding is BINARY" do
        a = "abc".dup.force_encoding("binary")
        @s.rb_str_conv_enc_opts(a, Encoding::US_ASCII,
                                Encoding::BINARY, 0, nil).should equal(a)
      end
    end
  end

  describe "rb_str_export" do
    it "returns the original String with the external encoding" do
      Encoding.default_external = Encoding::ISO_8859_1
      s = @s.rb_str_export("Hëllo")
      s.encoding.should equal(Encoding::ISO_8859_1)
    end
  end

  describe "rb_str_export_locale" do
    it "returns the original String with the locale encoding" do
      s = @s.rb_str_export_locale("abc")
      s.should == "abc".dup.force_encoding(Encoding.find("locale"))
      s.encoding.should equal(Encoding.find("locale"))
    end
  end

  describe "rb_str_export_to_enc" do
    it "returns a copy of an ascii string converted to the new encoding" do
      source = "A simple string".encode(Encoding::US_ASCII)
      result = @s.rb_str_export_to_enc(source, Encoding::UTF_8)
      result.should == source.encode(Encoding::UTF_8)
      result.encoding.should == Encoding::UTF_8
    end

    it "returns the source string if it can not be converted" do
      source = ["00ff"].pack("H*");
      result = @s.rb_str_export_to_enc(source, Encoding::UTF_8)
      result.should equal(source)
    end

    it "does not alter the source string if it can not be converted" do
      source = ["00ff"].pack("H*");
      result = @s.rb_str_export_to_enc(source, Encoding::UTF_8)
      source.bytes.should == [0, 255]
    end
  end

  describe "rb_sprintf" do
    it "replaces the parts like sprintf" do
      @s.rb_sprintf1("Awesome %s is replaced", "string").should == "Awesome string is replaced"
      @s.rb_sprintf1("%s", "TestFoobarTest").should == "TestFoobarTest"
    end

    it "accepts multiple arguments" do
      s = "Awesome %s is here with %s"
      @s.rb_sprintf2(s, "string", "content").should == "Awesome string is here with content"
    end

    it "formats a string VALUE using to_s if sign not specified in format" do
      s = 'Result: A string.'
      @s.rb_sprintf3(CApiStringSpecs::ToSOrInspect.new).should == s
    end

    it "formats a string VALUE using inspect if sign specified in format" do
      s = 'Result: A different string.'
      @s.rb_sprintf4(CApiStringSpecs::ToSOrInspect.new).should == s
    end

    it "formats a TrueClass VALUE as `TrueClass` if sign not specified in format" do
      s = 'Result: TrueClass.'
      @s.rb_sprintf3(true.class).should == s
    end

    it "formats a TrueClass VALUE as 'true' if sign specified in format" do
      s = 'Result: TrueClass.'
      @s.rb_sprintf4(true.class).should == s
    end

    it "formats nil using to_s if sign not specified in format" do
      s = 'Result: .'
      @s.rb_sprintf3(nil).should == s
    end

    it "formats nil using inspect if sign specified in format" do
      s = 'Result: nil.'
      @s.rb_sprintf4(nil).should == s
    end

    it "truncates a string to a supplied precision if that is shorter than the string" do
      s = 'Result: Hel.'
      @s.rb_sprintf5(0, 3, "Hello").should == s
    end

    it "does not truncates a string to a supplied precision if that is longer than the string" do
      s = 'Result: Hello.'
      @s.rb_sprintf5(0, 8, "Hello").should == s
    end

    it "pads a string to a supplied width if that is longer than the string" do
      s = 'Result:    Hello.'
      @s.rb_sprintf5(8, 5, "Hello").should == s
    end

    it "truncates a VALUE string to a supplied precision if that is shorter than the VALUE string" do
      s = 'Result: Hel.'
      @s.rb_sprintf6(0, 3, "Hello").should == s
    end

    it "does not truncates a VALUE string to a supplied precision if that is longer than the VALUE string" do
      s = 'Result: Hello.'
      @s.rb_sprintf6(0, 8, "Hello").should == s
    end

    it "pads a VALUE string to a supplied width if that is longer than the VALUE string" do
      s = 'Result:    Hello.'
      @s.rb_sprintf6(8, 5, "Hello").should == s
    end

    it "can format a nil VALUE as a pointer and gives the same output as sprintf in C" do
      res = @s.rb_sprintf7("%p", nil);
      res[0].should == res[1]
    end

    it "can format a string VALUE as a pointer and gives the same output as sprintf in C" do
      res = @s.rb_sprintf7("%p", "Hello")
      res[0].should == res[1]
    end

    it "can format a raw number a pointer and gives the same output as sprintf in C" do
      res = @s.rb_sprintf7("%p", 0x223643);
      res[0].should == res[1]
    end
  end

  describe "rb_vsprintf" do
    it "returns a formatted String from a variable number of arguments" do
      s = @s.rb_vsprintf("%s, %d, %.2f", "abc", 42, 2.7);
      s.should == "abc, 42, 2.70"
    end
  end

  describe "rb_String" do
    it "returns the passed argument if it is a string" do
      @s.rb_String("a").should == "a"
    end

    it "tries to convert the passed argument to a string by calling #to_str first" do
      @s.rb_String(CApiStringSpecs::ValidTostrTest.new).should == "ruby"
    end

    it "raises a TypeError if #to_str does not return a string" do
      -> { @s.rb_String(CApiStringSpecs::InvalidTostrTest.new) }.should raise_error(TypeError)
    end

    it "tries to convert the passed argument to a string by calling #to_s" do
      @s.rb_String({"bar" => "foo"}).should == {"bar" => "foo"}.to_s
    end
  end

  describe "rb_string_value_cstr" do
    it "returns a non-null pointer for a simple string" do
      @s.rb_string_value_cstr("Hello").should == true
    end

    it "returns a non-null pointer for a UTF-16 string" do
      @s.rb_string_value_cstr("Hello".encode('UTF-16BE')).should == true
    end

    it "raises an error if a string contains a null" do
      -> { @s.rb_string_value_cstr("Hello\0 with a null.") }.should raise_error(ArgumentError)
    end

    it "raises an error if a UTF-16 string contains a null" do
      -> { @s.rb_string_value_cstr("Hello\0 with a null.".encode('UTF-16BE')) }.should raise_error(ArgumentError)
    end

  end

  describe "rb_str_drop_bytes" do
    it "drops N characters for an ASCII string" do
      str = "12345678".encode("US-ASCII")
      @s.rb_str_drop_bytes(str, 4)
      str.should == "5678".encode("US-ASCII")
    end

    it "drop N/2 characters for a UTF-16 string" do
      str = "12345678".encode("UTF-16LE")
      @s.rb_str_drop_bytes(str, 4)
      str.should == "345678".encode("UTF-16LE")
    end

    it "drop N/4 characters for a UTF-32 string" do
      str = "12345678".encode("UTF-32LE")
      @s.rb_str_drop_bytes(str, 4)
      str.should == "2345678".encode("UTF-32LE")
    end
  end

  describe "rb_utf8_str_new_static" do
    it "returns a UTF-8 string of the correct characters and length" do
      str = @s.rb_utf8_str_new_static
      str.should == "nokogiri"
      str.encoding.should == Encoding::UTF_8
    end
  end

  describe "rb_utf8_str_new" do
    it "returns a UTF-8 string of the correct characters and length" do
      str = @s.rb_utf8_str_new
      str.should == "nokogiri"
      str.encoding.should == Encoding::UTF_8
    end
  end

  describe "rb_utf8_str_new_cstr" do
    it "returns a UTF-8 string of the correct characters and length" do
      str = @s.rb_utf8_str_new_cstr
      str.should == "nokogiri"
      str.encoding.should == Encoding::UTF_8
    end
  end

  describe "rb_str_vcatf" do
    it "appends the message to the string" do
      @s.rb_str_vcatf("").should == "fmt 42 7 number"

      str = "test "
      @s.rb_str_vcatf(str)
      str.should == "test fmt 42 7 number"
    end
  end

  describe "rb_str_catf" do
    it "appends the message to the string" do
      @s.rb_str_catf("").should == "fmt 41 6 number"

      str = "test "
      @s.rb_str_catf(str)
      str.should == "test fmt 41 6 number"
    end
  end

  describe "rb_str_locktmp" do
    it "raises an error when trying to lock an already locked string" do
      str = +"test"
      @s.rb_str_locktmp(str).should == str
      -> { @s.rb_str_locktmp(str) }.should raise_error(RuntimeError, 'temporal locking already locked string')
    end

    it "locks a string so that modifications would raise an error" do
      str = +"test"
      @s.rb_str_locktmp(str).should == str
      -> { str.upcase! }.should raise_error(RuntimeError, 'can\'t modify string; temporarily locked')
    end

    ruby_version_is "3.5" do
      it "raises FrozenError if string is frozen" do
        str = -"rb_str_locktmp"
        -> { @s.rb_str_locktmp(str) }.should raise_error(FrozenError)

        str = +"rb_str_locktmp"
        str.freeze
        -> { @s.rb_str_locktmp(str) }.should raise_error(FrozenError)
      end
    end
  end

  describe "rb_str_unlocktmp" do
    it "unlocks a locked string" do
      str = +"test"
      @s.rb_str_locktmp(str)
      @s.rb_str_unlocktmp(str).should == str
      str.upcase!.should == "TEST"
    end

    it "raises an error when trying to unlock an already unlocked string" do
      -> { @s.rb_str_unlocktmp(+"test") }.should raise_error(RuntimeError, 'temporal unlocking already unlocked string')
    end

    ruby_version_is "3.5" do
      it "raises FrozenError if string is frozen" do
        str = -"rb_str_locktmp"
        -> { @s.rb_str_unlocktmp(str) }.should raise_error(FrozenError)

        str = +"rb_str_locktmp"
        str.freeze
        -> { @s.rb_str_unlocktmp(str) }.should raise_error(FrozenError)
      end
    end
  end

  describe "rb_enc_interned_str_cstr" do
    it "returns a frozen string" do
      str = "hello"
      val = @s.rb_enc_interned_str_cstr(str, Encoding::US_ASCII)

      val.should.is_a?(String)
      val.encoding.should == Encoding::US_ASCII
      val.should.frozen?
    end

    it "returns the same frozen string" do
      str = "hello"
      result1 = @s.rb_enc_interned_str_cstr(str, Encoding::US_ASCII)
      result2 = @s.rb_enc_interned_str_cstr(str, Encoding::US_ASCII)
      result1.should.equal?(result2)
    end

    it "returns different frozen strings for different encodings" do
      str = "hello"
      result1 = @s.rb_enc_interned_str_cstr(str, Encoding::US_ASCII)
      result2 = @s.rb_enc_interned_str_cstr(str, Encoding::UTF_8)
      result1.should_not.equal?(result2)
    end

    it "returns the same string as String#-@" do
      @s.rb_enc_interned_str_cstr("hello", Encoding::UTF_8).should.equal?(-"hello")
    end

    ruby_bug "#20322", ""..."3.4" do
      it "uses the default encoding if encoding is null" do
        str = "hello"
        val = @s.rb_enc_interned_str_cstr(str, nil)
        val.encoding.should == Encoding::ASCII_8BIT
      end
    end
  end

  describe "rb_enc_interned_str" do
    it "returns a frozen string" do
      str = "hello"
      val = @s.rb_enc_interned_str(str, str.bytesize, Encoding::US_ASCII)

      val.should.is_a?(String)
      val.encoding.should == Encoding::US_ASCII
      val.should.frozen?
    end

    it "returns the same frozen string" do
      str = "hello"
      result1 = @s.rb_enc_interned_str(str, str.bytesize, Encoding::US_ASCII)
      result2 = @s.rb_enc_interned_str(str, str.bytesize, Encoding::US_ASCII)
      result1.should.equal?(result2)
    end

    it "returns different frozen strings for different encodings" do
      str = "hello"
      result1 = @s.rb_enc_interned_str(str, str.bytesize, Encoding::US_ASCII)
      result2 = @s.rb_enc_interned_str(str, str.bytesize, Encoding::UTF_8)
      result1.should_not.equal?(result2)
    end

    it 'returns the same string when using non-ascii characters' do
      str = 'こんにちは'
      result1 = @s.rb_enc_interned_str(str, str.bytesize, Encoding::UTF_8)
      result2 = @s.rb_enc_interned_str(str, str.bytesize, Encoding::UTF_8)
      result1.should.equal?(result2)
    end

    it "returns the same string as String#-@" do
      str = "hello"
      @s.rb_enc_interned_str(str, str.bytesize, Encoding::UTF_8).should.equal?(-str)
    end

    ruby_bug "#20322", ""..."3.4" do
      it "uses the default encoding if encoding is null" do
        str = "hello"
        val = @s.rb_enc_interned_str(str, str.bytesize, nil)
        val.encoding.should == Encoding::ASCII_8BIT
      end
    end
  end

  describe "rb_str_to_interned_str" do
    it "returns a frozen string" do
      str = "hello"
      result = @s.rb_str_to_interned_str(str)
      result.should.is_a?(String)
      result.should.frozen?
    end

    it "returns the same frozen string" do
      str = "hello"
      result1 = @s.rb_str_to_interned_str(str)
      result2 = @s.rb_str_to_interned_str(str)
      result1.should.equal?(result2)
    end

    it "returns different frozen strings for different encodings" do
      result1 = @s.rb_str_to_interned_str("hello".dup.force_encoding(Encoding::US_ASCII))
      result2 = @s.rb_str_to_interned_str("hello".dup.force_encoding(Encoding::UTF_8))
      result1.should_not.equal?(result2)
    end

    it "returns the same string as String#-@" do
      @s.rb_str_to_interned_str("hello").should.equal?(-"hello")
    end
  end
end
