# -*- coding: us-ascii -*-

# Used to expand Ruby template files by common.mk, uncommon.mk and
# some Ruby extension libraries.

require 'erb'
require 'optparse'
require_relative 'lib/output'

out = Output.new
dump = nil
templates = []

ARGV.options do |o|
  o.on('-i', '--input=PATH') {|v| templates << v}
  o.on('-x', '--source') {dump = :src}
  o.on('--dump=TYPE', %i[insn src result]) {|v| dump = v}
  out.def_options(o)
  o.order!(ARGV)
  templates << (ARGV.shift or abort o.to_s) if templates.empty?
end

# Used in prelude.c.tmpl and unicode_norm_gen.tmpl
output = out.path
vpath = out.vpath

# A hack to prevent "unused variable" warnings
output, vpath = output, vpath

result = templates.map do |template|
  erb = ERB.new(File.read(template), trim_mode: '%-')
  erb.filename = template
  case dump
  when :src
    erb.src
  when :insn
    RubyVM::InstructionSequence.compile(erb.src, erb.filename, nil, 0).disasm
  else
    proc{erb.result(binding)}.call
  end
end
result = result.size == 1 ? result[0] : result.join("")
out.write(result)
