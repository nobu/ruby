#!ruby -s

OPTIMIZATION = {
  inline_const_cache: true,
  peephole_optimization: true,
  tailcall_optimization: false,
  specialized_instruction: true,
  operands_unification: true,
  instructions_unification: true,
  frozen_string_literal: true,
  debug_frozen_string_literal: false,
  coverage_enabled: false,
  debug_level: 0,
}

file = File.basename(ARGV[0], ".rb")
name = "<internal:#{file}>"
iseq = RubyVM::InstructionSequence.compile(ARGF.read, name, name, **OPTIMIZATION)
bin = iseq.to_binary
puts <<C
/* -*- C -*- */

static const union {
    unsigned char binary[#{bin.size}];
    uint32_t align_as_ibf_header;
} #{file}_builtin = {
    .binary = {
C
bin.bytes.each_slice(12) do |b|
  print "        ", b.map {|c| "0x%.2x," % c}.join(" ")
  if $comment
    print " /* ", b.pack("C*").gsub(/([[ -~]&&[^\\]])|(?m:.)/) {
      (c = $1) ? "#{c} " : (c = $&.dump).size == 2 ? c : ". "
    }, "*/"
  end
  puts
end
puts <<C
    }
};

#include "ruby/ruby.h"
#include "vm_core.h"

void
Init_#{file}(void)
{
    const char *builtin = (const char *)#{file}_builtin.binary;
    size_t size = sizeof(#{file}_builtin);
    VALUE code = rb_str_new_static(builtin, (long)size);
    VALUE iseq = rb_funcallv(rb_cISeq, rb_intern_const("load_from_binary"), 1, &code);
    rb_iseq_eval_main(rb_iseqw_to_iseq(iseq));
}
C
