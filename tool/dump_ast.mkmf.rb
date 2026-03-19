#!ruby -s

require 'rbconfig'

# Achieve the configurations on build OS.
cc, outflag, exeext = RbConfig::CONFIG.values_at(*%w"CC OUTFLAG EXEEXT")

target, src, *objs = ARGV
srcdir = File.dirname(File.dirname(src))
dirs = objs.map {|obj| File.dirname(obj)}.uniq - %w[.]
srcs = objs.map {|obj| '$(srcdir)/' + obj.sub(/\.[^.]+\z/, '.c')}

print(<<~MAKEFILE)
srcdir = #{srcdir}
target = #{target}#{exeext}
srcs = #{src} #{srcs.join(' ')}
CC = #{cc}

$(target): $(srcs)
\t$(CC) #{outflag}$@ -I$(srcdir)/prism -I$(srcdir) $(srcs)

clean:
\t$(RMALL) $(target) $(target).*
MAKEFILE
