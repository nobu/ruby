# encoding: utf-8
# fronzen-string-literal: true

# Document-module: Warning
#
# The Warning module contains a single method named #warn, and the
# module extends itself, making Warning.warn available.
# Warning.warn is called for all warnings issued by Ruby.
# By default, warnings are printed to $stderr.
#
# By overriding Warning.warn, you can change how warnings are
# handled by Ruby, either filtering some warnings, and/or outputting
# warnings somewhere other than $stderr.  When Warning.warn is
# overridden, super can be called to get the default behavior of
# printing the warning to $stderr.
module Warning

  # call-seq:
  #    warn(msg)  -> nil
  #
  # Writes warning message +msg+ to $stderr. This method is called by
  # Ruby for all emitted warnings.
  def self.warn(str, category: no_category = true)
    __builtin_inline! %q{
        Check_Type(str, T_STRING);
        rb_must_asciicompat(str);
        if (RTEST(no_category) || rb_warning_category_enabled_p(category)) {
            rb_write_error_str(str);
        }
        return Qnil;
    }
  end
end
