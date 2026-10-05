#!ruby
# Converts the configuration part of Makefile, which win32/configure.bat
# generated for nmake, to GNUmakefile.  EXPERIMENTAL.

src = File.binread(ARGV[0] || "Makefile").gsub(/\r\n/, "\n")
src.sub!(/^MAKE = nmake\n/, "")
src.gsub!(/^!if.*?^!endif\n/m, "")
src.sub!(/^!include (.*)Makefile\.sub$/) {"include #{$1}GNUmakefile.sub"} or
  abort "no Makefile.sub inclusion found"
File.binwrite(ARGV[1] || "GNUmakefile", src)
