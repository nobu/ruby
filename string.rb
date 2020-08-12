=begin
This file is just for the RDoc now, to allow non US-ASCII characters.
As C does not have the fixed encoding, such characters are locale dependent.
=end

class String
  # call-seq:
  #    String.new(str='')                   -> new_str
  #    String.new(str='', encoding: enc)    -> new_str
  #    String.new(str='', capacity: size)   -> new_str
  #
  # Argument +str+, if given, it must be a
  # {String-convertible object}[doc/implicit_conversion_rdoc.html#label-String-Convertible+Objects]
  # (implements +to_str).
  #
  # Argument +encoding+, if given, must be:
  # - A {String-convertible object}[doc/implicit_conversion_rdoc.html#label-String-Convertible+Objects]
  #   (implements +to_str+).
  # - The name of an encoding that is compatible with +str+.
  #
  # Argument +capacity+, if given, must be an
  # {Integer-convertible object}[doc/implicit_conversion_rdoc.html#label-Integer-Convertible+Objects]
  # (implements +to_int+).
  #
  # The +str+, +encoding+, and +capacity+ arguments may all be used together:
  #   String.new('hello', encoding: 'UTF-8', capacity: 25)
  #
  # Returns a new \String that is a copy of <i>str</i>.
  #
  # ---
  #
  # With no arguments, returns the empty string with the Encoding <tt>ASCII-8BIT</tt>:
  #   s = String.new
  #   s # => ""
  #   s.encoding # => #<Encoding:ASCII-8BIT>
  #
  # With the single argument +str+, returns a copy of +str+
  # with the same encoding as +str+:
  #   s = String.new('Que veut dire ça?')
  #   s # => "Que veut dire ça?"
  #   s.encoding # => #<Encoding:UTF-8>
  #
  # Literal strings like <tt>""</tt> or here-documents always use
  # {script encoding}[Encoding.html#class-Encoding-label-Script+encoding], unlike String.new.
  #
  # ---
  #
  # With keyword +encoding+, returns a copy of +str+
  # with the specified encoding:
  #   s = String.new(encoding: 'ASCII')
  #   s.encoding # => #<Encoding:US-ASCII>
  #   s = String.new('foo', encoding: 'ASCII')
  #   s.encoding # => #<Encoding:US-ASCII>
  #
  # Note that these are equivalent:
  #   s0 = String.new('foo', encoding: 'ASCII')
  #   s1 = 'foo'.force_encoding('ASCII')
  #   s0.encoding == s1.encoding # => true
  #
  # ---
  #
  # With keyword +capacity+, returns a copy of +str+;
  # the given +capacity+ may set the size of the internal buffer,
  # which may affect performance:
  #   String.new(capacity: 1) # => ""
  #   String.new(capacity: 4096) # => ""
  #
  # No exception is raised for zero or negative values:
  #   String.new(capacity: 0) # => ""
  #   String.new(capacity: -1) # => ""
  #
  # ---
  #
  # Raises an exception if +str+ is not \String-convertible:
  #   # Raises TypeError (no implicit conversion of Integer into String):
  #   String.new(0)
  #
  # Raises an exception if +encoding+ is not \String-convertible
  # or an Encoding object:
  #   # Raises TypeError (no implicit conversion of Integer into String):
  #   String.new(encoding: 0)
  #
  # Raises an exception if the given +encoding+ is not a valid encoding name:
  #   # Raises ArgumentError (unknown encoding name - FOO)
  #   String.new(encoding: 'FOO')
  #
  # Raises an exception if the given +encoding+ is incompatible with +str+:
  #   utf8 = 'Que veut dire ça?'
  #   ascii = 'Que veut dire ça?'.force_encoding('ASCII')
  #   # Raises Encoding::CompatibilityError (incompatible character encodings: UTF-8 and US-ASCII)
  #   utf8.include? ascii
  #
  # Raises an exception if +capacity+ is not \Integer-convertible:
  #   # Raises TypeError (no implicit conversion of Symbol into Integer):
  #   String.new(capacity: :foo)
  #
  def initialize(orig = nil, encoding: nil, capacity: nil)
    Primitive.rb_str_init(orig, encoding, capacity)
  end
end
