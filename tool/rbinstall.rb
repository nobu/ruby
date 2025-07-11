#!./miniruby

# Used by the "make install" target to install Ruby.
# See common.mk for more details.

ENV["SDKROOT"] ||= "" if /darwin/ =~ RUBY_PLATFORM

begin
  load "./rbconfig.rb"
rescue LoadError
  CONFIG = Hash.new {""}
else
  include RbConfig
  $".unshift File.expand_path("./rbconfig.rb")
end

srcdir = File.expand_path('../..', __FILE__)
unless defined?(CROSS_COMPILING) and CROSS_COMPILING
  $:.replace([srcdir+"/lib", Dir.pwd])
end
require 'fileutils'
require 'shellwords'
require 'optparse'
require 'optparse/shellwords'
require 'rubygems'
begin
  require "zlib"
rescue LoadError
  $" << "zlib.rb"
end
require_relative 'lib/path'

INDENT = " "*36
STDOUT.sync = true
File.umask(022)

def parse_args(argv = ARGV)
  $mantype = 'doc'
  $destdir = nil
  $extout = nil
  $make = 'make'
  $mflags = []
  $install = []
  $installed = {}
  $installed_list = nil
  $exclude = []
  $dryrun = false
  $rdocdir = nil
  $htmldir = nil
  $data_mode = 0644
  $prog_mode = 0755
  $dir_mode = nil
  $script_mode = nil
  $strip = false
  $debug_symbols = nil
  $cmdtype = (if File::ALT_SEPARATOR == '\\'
                File.exist?("rubystub.exe") ? 'exe' : 'cmd'
              end)
  mflags = []
  gnumake = false
  opt = OptionParser.new
  opt.on('-n', '--dry-run') {$dryrun = true}
  opt.on('--dest-dir=DIR') {|dir| $destdir = dir}
  opt.on('--extout=DIR') {|dir| $extout = (dir unless dir.empty?)}
  opt.on('--ext-build-dir=DIR') {|v| $ext_build_dir = v }
  opt.on('--make=COMMAND') {|make| $make = make}
  opt.on('--mantype=MAN') {|man| $mantype = man}
  opt.on('--make-flags=FLAGS', '--mflags', Shellwords) do |v|
    if arg = v.first
      arg.insert(0, '-') if /\A[^-][^=]*\Z/ =~ arg
    end
    $mflags.concat(v)
  end
  opt.on('-i', '--install=TYPE', $install_procs.keys) do |ins|
    $install << ins
  end
  opt.on('-x', '--exclude=TYPE', $install_procs.keys) do |exc|
    $exclude << exc
  end
  opt.on('--data-mode=OCTAL-MODE', OptionParser::OctalInteger) do |mode|
    $data_mode = mode
  end
  opt.on('--prog-mode=OCTAL-MODE', OptionParser::OctalInteger) do |mode|
    $prog_mode = mode
  end
  opt.on('--dir-mode=OCTAL-MODE', OptionParser::OctalInteger) do |mode|
    $dir_mode = mode
  end
  opt.on('--script-mode=OCTAL-MODE', OptionParser::OctalInteger) do |mode|
    $script_mode = mode
  end
  opt.on('--installed-list [FILENAME]') {|name| $installed_list = name}
  opt.on('--rdoc-output [DIR]') {|dir| $rdocdir = dir}
  opt.on('--html-output [DIR]') {|dir| $htmldir = dir}
  opt.on('--cmd-type=TYPE', %w[cmd plain]) {|cmd| $cmdtype = (cmd unless cmd == 'plain')}
  opt.on('--[no-]strip') {|strip| $strip = strip}
  opt.on('--gnumake') {gnumake = true}
  opt.on('--debug-symbols=SUFFIX', /\w+/) {|name| $debug_symbols = ".#{name}"}

  unless $install_procs.empty?
    w = (w = ENV["COLUMNS"] and (w = w.to_i) > 80) ? w - 30 : 50
    opt.on("\n""Types for --install and --exclude:")
    mesg = +" "
    $install_procs.each_key do |t|
      if mesg.size + t.size > w
        opt.on(mesg)
        mesg = +" "
      end
      mesg << " " << t.to_s
    end
    opt.on(mesg)
  end

  opt.order!(argv) do |v|
    case v
    when /\AINSTALL[-_]([-\w]+)=(.*)/
      argv.unshift("--#{$1.tr('_', '-')}=#{$2}")
    when /\A\w[-\w]*=/
      mflags << v
    when /\A\w[-\w+]*\z/
      $install << v.intern
    else
      raise OptionParser::InvalidArgument, v
    end
  end rescue abort "#{$!.message}\n#{opt.help}"

  unless defined?(RbConfig)
    puts opt.help
    exit
  end

  $make, *rest = Shellwords.shellwords($make)
  $mflags.unshift(*rest) unless rest.empty?
  $mflags.unshift(*mflags)
  $mflags.reject! {|v| /\A-[OW]/ =~ v} if gnumake

  def $mflags.set?(flag)
    grep(/\A-(?!-).*#{flag.chr}/i) { return true }
    false
  end
  def $mflags.defined?(var)
    grep(/\A#{var}=(.*)/) {return block_given? ? yield($1) : $1}
    false
  end

  if $mflags.set?(?n)
    $dryrun = true
  else
    $mflags << '-n' if $dryrun
  end

  $destdir ||= $mflags.defined?("DESTDIR")
  $destdir = File.expand_path($destdir) unless $destdir.empty?
  if $extout ||= $mflags.defined?("EXTOUT")
    RbConfig.expand($extout)
  end

  $continue = $mflags.set?(?k)

  if $installed_list ||= $mflags.defined?('INSTALLED_LIST')
    RbConfig.expand($installed_list, RbConfig::CONFIG)
    $installed_list = File.open($installed_list, "ab")
    $installed_list.sync = true
  end

  $rdocdir ||= $mflags.defined?('RDOCOUT')
  $htmldir ||= $mflags.defined?('HTMLOUT')

  $dir_mode ||= $prog_mode | 0700
  $script_mode ||= $prog_mode
  if $ext_build_dir.nil?
    raise OptionParser::MissingArgument.new("--ext-build-dir=DIR")
  end
end

Compressors = {".gz"=>"gzip", ".bz2"=>"bzip2"}
def Compressors.for(type)
  ext = File.extname(type)
  if compress = fetch(ext, nil)
    [type.chomp(ext), ext, compress]
  else
    [type, *find {|_, z| system(z, in: IO::NULL, out: IO::NULL)}]
  end
end

$install_procs = Hash.new {[]}
def install?(*types, &block)
  unless types.delete(:nodefault)
    $install_procs[:all] <<= block
  end
  types.each do |type|
    $install_procs[type] <<= block
  end
end

def strip_file(files)
  if !defined?($strip_command) and (cmd = CONFIG["STRIP"])
    case cmd
    when "", "true", ":" then return
    else $strip_command = Shellwords.shellwords(cmd)
    end
  elsif !$strip_command
    return
  end
  system(*($strip_command + [files].flatten))
end

def install(src, dest, options = {})
  options = options.clone
  strip = options.delete(:strip)
  options[:preserve] = true
  srcs = Array(src).select {|s| !$installed[$made_dirs[dest] ? File.join(dest, s) : dest]}
  return if srcs.empty?
  src = srcs if Array === src
  d = with_destdir(dest)
  super(src, d, **options)
  srcs.each {|s| $installed[$made_dirs[dest] ? File.join(dest, s) : dest] = true}
  if strip
    d = srcs.map {|s| File.join(d, File.basename(s))} if $made_dirs[dest]
    strip_file(d)
  end
  if $installed_list
    dest = srcs.map {|s| File.join(dest, File.basename(s))} if $made_dirs[dest]
    $installed_list.puts dest
  end
end

def ln_sf(src, dest)
  super(src, with_destdir(dest))
  $installed_list.puts dest if $installed_list
end

$made_dirs = {}

def dir_creating(dir)
  $made_dirs.fetch(dir) do
    $made_dirs[dir] = true
    $installed_list.puts(File.join(dir, "")) if $installed_list
    yield if defined?(yield)
  end
end

def makedirs(dirs)
  dirs = fu_list(dirs)
  dirs.collect! do |dir|
    realdir = with_destdir(dir)
    realdir unless dir_creating(dir) {File.directory?(realdir)}
  end.compact!
  super(dirs, :mode => $dir_mode) unless dirs.empty?
end

FalseProc = proc {false}
def path_matcher(pat)
  if pat and !pat.empty?
    proc {|f| pat.any? {|n| File.fnmatch?(n, f)}}
  else
    FalseProc
  end
end

def install_recursive(srcdir, dest, options = {})
  opts = options.clone
  noinst = opts.delete(:no_install)
  glob = opts.delete(:glob) || "*"
  maxdepth = opts.delete(:maxdepth)
  subpath = (srcdir.size+1)..-1
  prune = []
  skip = []
  if noinst
    if Array === noinst
      prune = noinst.grep(/#{File::SEPARATOR}/o).map!{|f| f.chomp(File::SEPARATOR)}
      skip = noinst.grep(/\A[^#{File::SEPARATOR}]*\z/o)
    else
      if noinst.index(File::SEPARATOR)
        prune = [noinst]
      else
        skip = [noinst]
      end
    end
  end
  skip |= %w"#*# *~ *.old *.bak *.orig *.rej *.diff *.patch *.core"
  prune = path_matcher(prune)
  skip = path_matcher(skip)
  File.directory?(srcdir) or return rescue return
  paths = [[srcdir, dest, 0]]
  found = []
  while file = paths.shift
    found << file
    file, d, dir = *file
    if dir
      depth = dir + 1
      next if maxdepth and maxdepth < depth
      files = []
      Dir.foreach(file) do |f|
        src = File.join(file, f)
        d = File.join(dest, dir = src[subpath])
        stat = File.lstat(src) rescue next
        if stat.directory?
          files << [src, d, depth] if maxdepth != depth and /\A\./ !~ f and !prune[dir]
        elsif stat.symlink?
          # skip
        else
          files << [src, d, false] if File.fnmatch?(glob, f, File::FNM_EXTGLOB) and !skip[f]
        end
      end
      paths.insert(0, *files)
    end
  end
  for src, d, dir in found
    if dir
      next
      # makedirs(d)
    else
      makedirs(d[/.*(?=\/)/m])
      if block_given?
        yield src, d, opts
      else
        install src, d, opts
      end
    end
  end
end

def open_for_install(path, mode)
  data = File.binread(realpath = with_destdir(path)) rescue nil
  newdata = yield
  unless $dryrun
    unless newdata == data
      File.open(realpath, "wb", mode) {|f| f.write newdata}
    end
    File.chmod(mode, realpath)
  end
  $installed_list.puts path if $installed_list
end

def with_destdir(dir)
  return dir if !$destdir or $destdir.empty?
  dir = dir.sub(/\A\w:/, '') if File::PATH_SEPARATOR == ';'
  $destdir + dir
end

def without_destdir(dir)
  return dir if !$destdir or $destdir.empty?
  dir.start_with?($destdir) ? dir[$destdir.size..-1] : dir
end

def prepare(mesg, basedir, subdirs=nil)
  return unless basedir
  case
  when !subdirs
    dirs = basedir
  when subdirs.size == 0
    subdirs = nil
  when subdirs.size == 1
    dirs = [basedir = File.join(basedir, subdirs)]
    subdirs = nil
  else
    dirs = [basedir, *subdirs.collect {|dir| File.join(basedir, dir)}]
  end
  printf("%-*s%s%s\n", INDENT.size, "installing #{mesg}:", basedir,
         (subdirs ? " (#{subdirs.join(', ')})" : ""))
  makedirs(dirs)
end

def CONFIG.[](name, mandatory = false)
  value = super(name)
  if mandatory
    raise "CONFIG['#{name}'] must be set" if !value or value.empty?
  end
  value
end

exeext = CONFIG["EXEEXT"]

ruby_install_name = CONFIG["ruby_install_name", true]
rubyw_install_name = CONFIG["rubyw_install_name"]
goruby_install_name = "go" + ruby_install_name

bindir = CONFIG["bindir", true]
if CONFIG["libdirname"] == "archlibdir"
  archbindir = bindir.sub(%r[/\K(?=[^/]+\z)]) {CONFIG["config_target"] + "/"}
end
libdir = CONFIG[CONFIG.fetch("libdirname", "libdir"), true]
rubyhdrdir = CONFIG["rubyhdrdir", true]
archhdrdir = CONFIG["rubyarchhdrdir"] || (rubyhdrdir + "/" + CONFIG['arch'])
rubylibdir = CONFIG["rubylibdir", true]
archlibdir = CONFIG["rubyarchdir", true]
if CONFIG["sitedir"]
  sitelibdir = CONFIG["sitelibdir"]
  sitearchlibdir = CONFIG["sitearchdir"]
end
if CONFIG["vendordir"]
  vendorlibdir = CONFIG["vendorlibdir"]
  vendorarchlibdir = CONFIG["vendorarchdir"]
end
mandir = CONFIG["mandir", true]
docdir = CONFIG["docdir", true]
enable_shared = CONFIG["ENABLE_SHARED"] == 'yes'
dll = CONFIG["LIBRUBY_SO", enable_shared]
lib = CONFIG["LIBRUBY", true]
arc = CONFIG["LIBRUBY_A", true]
load_relative = CONFIG["LIBRUBY_RELATIVE"] == 'yes'

rdoc_noinst = %w[created.rid]

prolog_script = <<EOS
bindir="#{load_relative ? '${0%/*}' : bindir.gsub(/\"/, '\\\\"')}"
EOS
if !load_relative and libpathenv = CONFIG["LIBPATHENV"]
  pathsep = File::PATH_SEPARATOR
  prolog_script << <<EOS
libdir="#{libdir.gsub(/\"/, '\\\\"')}"
export #{libpathenv}="$libdir${#{libpathenv}:+#{pathsep}$#{libpathenv}}"
EOS
end
prolog_script << %Q[exec "$bindir/#{ruby_install_name}" "-x" "$0" "$@"\n]
PROLOG_SCRIPT = {}
PROLOG_SCRIPT["exe"] = "#!#{bindir}/#{ruby_install_name}"
PROLOG_SCRIPT["cmd"] = <<EOS
:""||{ ""=> %q<-*- ruby -*-
@"%~dp0#{ruby_install_name}" -x "%~f0" %*
@exit /b %ERRORLEVEL%
};{ #\n#{prolog_script.gsub(/(?=\n)/, ' #')}>,\n}
EOS
PROLOG_SCRIPT.default = (load_relative || /\s/ =~ bindir) ?
                          <<EOS : PROLOG_SCRIPT["exe"]
#!/bin/sh
# -*- ruby -*-
_=_\\
=begin
#{prolog_script.chomp}
=end
EOS

installer = Struct.new(:ruby_shebang, :ruby_bin, :ruby_install_name, :stub, :trans) do
  def transform(name)
    RbConfig.expand(trans[name])
  end
end

$script_installer = Class.new(installer) do
  ruby_shebang = File.join(bindir, ruby_install_name)
  if File::ALT_SEPARATOR
    ruby_bin = ruby_shebang.tr(File::SEPARATOR, File::ALT_SEPARATOR)
  end
  if trans = CONFIG["program_transform_name"]
    exp = []
    trans.gsub!(/\$\$/, '$')
    trans.scan(%r[\G[\s;]*(/(?:\\.|[^/])*+/)?([sy])(\\?\W)((?:(?!\3)(?:\\.|.))*+)\3((?:(?!\3)(?:\\.|.))*+)\3([gi]*)]) do
      |addr, cmd, sep, pat, rep, opt|
      addr &&= Regexp.new(addr[/\A\/(.*)\/\z/, 1])
      case cmd
      when 's'
        next if pat == '^' and rep.empty?
        exp << [addr, (opt.include?('g') ? :gsub! : :sub!),
                Regexp.new(pat, opt.include?('i')), rep.gsub(/&/){'\&'}]
      when 'y'
        exp << [addr, :tr!, Regexp.quote(pat), rep]
      end
    end
    trans = proc do |base|
      exp.each {|addr, opt, pat, rep| base.__send__(opt, pat, rep) if !addr or addr =~ base}
      base
    end
  elsif /ruby/ =~ ruby_install_name
    trans = proc {|base| ruby_install_name.sub(/ruby/, base)}
  else
    trans = proc {|base| base}
  end

  def prolog(shebang)
    shebang.sub!(/\r$/, '')
    script = PROLOG_SCRIPT[$cmdtype]
    shebang.sub!(/\A(\#!.*?ruby\b)?/) do
      if script.end_with?("\n")
        script + ($1 || "#!ruby\n")
      else
        $1 ? script : "#{script}\n"
      end
    end
    shebang
  end

  def install(src, cmd)
    cmd = cmd.sub(/[^\/]*\z/m) {|n| transform(n)}

    shebang, body = File.open(src, "rb") do |f|
      next f.gets, f.read
    end
    shebang or raise "empty file - #{src}"
    shebang = prolog(shebang)
    body.gsub!(/\r$/, '')

    cmd << ".#{$cmdtype}" if $cmdtype
    open_for_install(cmd, $script_mode) do
      case $cmdtype
      when "exe"
        stub + shebang + body
      else
        shebang + body
      end
    end
  end

  def self.get_rubystub
    stubfile = "rubystub.exe"
    stub = File.open(stubfile, "rb") {|f| f.read} << "\n"
  rescue => e
    abort "No #{stubfile}: #{e}"
  else
    stub
  end

  def stub
    super or self.stub = self.class.get_rubystub
  end

  break new(ruby_shebang, ruby_bin, ruby_install_name, nil, trans)
end

module RbInstall
  def self.no_write(options = nil)
    u = File.umask(0022)
    if $dryrun
      fu = ::Object.class_eval do
        fu = remove_const(:FileUtils)
        const_set(:FileUtils, fu::NoWrite)
        fu
      end
      # RubyGems 3.0.0 or later supports `dir_mode`, but it uses
      # `File` method to apply it, not `FileUtils`.
      dir_mode = options.delete(:dir_mode) if options
    end
    yield
  ensure
    options[:dir_mode] = dir_mode if dir_mode
    if fu
      ::Object.class_eval do
        remove_const(:FileUtils)
        const_set(:FileUtils, fu)
      end
    end
    File.umask(u)
  end

  module Specs
    class FileCollector
      def self.for(srcdir, type, gemspec)
        relative_base = (File.dirname(gemspec) if gemspec.include?("/"))
        const_get(type.capitalize).new(gemspec, srcdir, relative_base)
      end

      attr_reader :gemspec, :srcdir, :relative_base
      def initialize(gemspec, srcdir, relative_base)
        @gemspec = gemspec
        @srcdir = srcdir
        @relative_base = relative_base
      end

      def collect
        requirable_features.sort
      end

      private

      def features_from_makefile(makefile_path)
        makefile = File.read(makefile_path)

        name = makefile[/^TARGET[ \t]*=[ \t]*((?:.*\\\n)*.*)/, 1]
        return [] if name.nil? || name.empty?

        feature = makefile[/^DLLIB[ \t]*=[ \t]*((?:.*\\\n)*.*)/, 1]
        feature = feature.sub("$(TARGET)", name)

        target_prefix = makefile[/^target_prefix[ \t]*=[ \t]*((?:.*\\\n)*.*)/, 1]
        feature = File.join(target_prefix.delete_prefix("/"), feature) unless target_prefix.empty?

        Array(feature)
      end

      class Ext < self
        def requirable_features
          # install ext only when it's configured
          return [] unless File.exist?(makefile_path)

          ruby_features + ext_features
        end

        private

        def ruby_features
          Dir.glob("**/*.rb", base: "#{makefile_dir}/lib")
        end

        def ext_features
          features_from_makefile(makefile_path)
        end

        def makefile_path
          if File.exist?("#{makefile_dir}/Makefile")
            "#{makefile_dir}/Makefile"
          else
            # for out-of-place build
            "#{$ext_build_dir}/#{relative_base}/Makefile"
          end
        end

        def makefile_dir
          "#{root}/#{relative_base}"
        end

        def root
          File.expand_path($ext_build_dir, srcdir)
        end
      end

      class Lib < self
        def requirable_features
          ruby_features + ext_features
        end

        private

        def ruby_features
          gemname = File.basename(gemspec, ".gemspec")
          base = relative_base || gemname
          # for lib/net/net-smtp.gemspec
          if m = /.*(?=-(.*)\z)/.match(gemname)
            base = File.join(base, *m.to_a.select {|n| !base.include?(n)})
          end
          files = Dir.glob("#{base}{.rb,/**/*.rb}", base: root)
          if !relative_base and files.empty? # no files at the toplevel
            # pseudo gem like ruby2_keywords
            files << "#{gemname}.rb"
          end

          case gemname
          when "net-http"
            files << "net/https.rb"
          when "optparse"
            files << "optionparser.rb"
          end

          files
        end

        def ext_features
          loaded_gemspec = load_gemspec("#{root}/#{gemspec}")
          extension = loaded_gemspec.extensions.first
          return [] unless extension

          extconf = File.expand_path(extension, srcdir)
          ext_build_dir = File.dirname(extconf)
          makefile_path = "#{ext_build_dir}/Makefile"
          return [] unless File.exist?(makefile_path)

          features_from_makefile(makefile_path)
        end

        def root
          "#{srcdir}/lib"
        end
      end

      class UnpackedGem < self
        def collect
          base = @srcdir or return []
          Dir.glob("**/*", File::FNM_DOTMATCH, base: base).select do |n|
            next if n == "."
            next if File.fnmatch?("*.gemspec", n, File::FNM_DOTMATCH|File::FNM_PATHNAME)
            !File.directory?(File.join(base, n))
          end
        end
      end
    end
  end

  class DirPackage
    attr_reader :spec

    attr_accessor :dir_mode
    attr_accessor :prog_mode
    attr_accessor :data_mode

    def initialize(spec, dir_map = nil)
      @spec = spec
      @src_dir = File.dirname(@spec.loaded_from)
      @dir_map = dir_map
    end

    def extract_files(destination_dir, pattern = "*")
      return if @src_dir == destination_dir
      File.chmod(0700, destination_dir) unless $dryrun
      mode = pattern == File.join(spec.bindir, '*') ? prog_mode : data_mode
      destdir = without_destdir(destination_dir)
      if @dir_map
        (dir_map = @dir_map.map {|k, v| Regexp.quote(k) unless k == v}).compact!
        dir_map = %r{\A(?:#{dir_map.join('|')})(?=/)}
      end
      spec.files.each do |f|
        next unless File.fnmatch(pattern, f)
        src = File.join(@src_dir, dir_map =~ f ? "#{@dir_map[$&]}#{$'}" : f)
        dest = File.join(destdir, f)
        makedirs(dest[/.*(?=\/)/m])
        install src, dest, :mode => mode
      end
      File.chmod(dir_mode, destination_dir) unless $dryrun
    end
  end

  class UnpackedInstaller < Gem::Installer
    def write_cache_file
    end

    def shebang(bin_file_name)
      path = File.join(gem_dir, spec.bindir, bin_file_name)
      first_line = File.open(path, "rb") {|file| file.gets}
      $script_installer.prolog(first_line).chomp
    end

    def app_script_text(bin_file_name)
      # move shell script part after comments generated by RubyGems.
      super.sub(/\A
        (\#!\/bin\/sh\n\#.*-\*-\s*ruby\s*-\*-.*\n)
        ((?:.*\n)*?\#!.*ruby.*\n)
        \#\n
        ((?:\#.*\n)+)/x, '\1\3\2')
    end

    def check_executable_overwrite(filename)
      return if @wrappers and same_bin_script?(filename, @bin_dir)
      super
    end

    def same_bin_script?(filename, bindir)
      path = File.join(bindir, formatted_program_filename(filename))
      begin
        return true if File.binread(path) == app_script_text(filename)
      rescue
      end
      false
    end

    def write_spec
      super unless $dryrun
      $installed_list.puts(without_destdir(spec_file)) if $installed_list
    end

    def write_default_spec
      super unless $dryrun
      $installed_list.puts(without_destdir(default_spec_file)) if $installed_list
    end

    def install
      spec.post_install_message = nil
      dir_creating(without_destdir(gem_dir))
      RbInstall.no_write(options) {super}
    end

    # Now build-ext builds all extensions including bundled gems.
    def build_extensions
    end

    def generate_bin_script(filename, bindir)
      return if same_bin_script?(filename, bindir)
      name = formatted_program_filename(filename)
      unless $dryrun
        super
        script = File.join(bindir, name)
        File.chmod($script_mode, script)
        File.unlink("#{script}.lock") rescue nil
      end
      $installed_list.puts(File.join(without_destdir(bindir), name)) if $installed_list
    end

    def verify_gem_home # :nodoc:
    end

    def ensure_writable_dir(dir)
      $made_dirs.fetch(d = without_destdir(dir)) do
        $made_dirs[d] = true
        super unless $dryrun
        $installed_list.puts(d+"/") if $installed_list
      end
    end

    def load_plugin
      # Suppress warnings for constant re-assignment
      verbose, $VERBOSE = $VERBOSE, nil
      super
    ensure
      $VERBOSE = verbose
    end
  end
end

def load_gemspec(file, base = nil, files: nil)
  file = File.realpath(file)
  code = File.read(file, encoding: "utf-8:-")

  code.gsub!(/^ *#.*/, "")
  files = files ? files.map(&:dump).join(", ") : ""
  code.gsub!(/(?:`git[^\`]*`|%x\[git[^\]]*\])\.split(\([^\)]*\))?/m) do
    "[" + files + "]"
  end \
  or
  code.gsub!(/IO\.popen\(.*git.*?\)/) do
    "[" + files + "] || itself"
  end

  spec = eval(code, binding, file)
  unless Gem::Specification === spec
    raise TypeError, "[#{file}] isn't a Gem::Specification (#{spec.class} instead)."
  end
  spec.loaded_from = base ? File.join(base, File.basename(file)) : file
  spec.date = RUBY_RELEASE_DATE

  spec
end

def install_default_gem(dir, srcdir, bindir)
  gem_dir = Gem.default_dir
  install_dir = with_destdir(gem_dir)
  prepare "default gems from #{dir}", gem_dir
  RbInstall.no_write do
    # Record making directories
    makedirs(Gem.ensure_default_gem_subdirectories(install_dir, $dir_mode).map {|d| File.join(gem_dir, d)})
  end

  options = {
    :install_dir => with_destdir(gem_dir),
    :bin_dir => with_destdir(bindir),
    :ignore_dependencies => true,
    :dir_mode => $dir_mode,
    :data_mode => $data_mode,
    :prog_mode => $script_mode,
    :wrappers => true,
    :format_executable => true,
    :install_as_default => true,
  }
  default_spec_dir = Gem.default_specifications_dir

  base = "#{srcdir}/#{dir}"
  gems = Dir.glob("**/*.gemspec", base: base).map {|src|
    files = RbInstall::Specs::FileCollector.for(srcdir, dir, src).collect
    if files.empty?
      next
    end
    load_gemspec("#{base}/#{src}", files: files)
  }
  gems.compact.sort_by(&:name).each do |gemspec|
    old_gemspecs = Dir[File.join(with_destdir(default_spec_dir), "#{gemspec.name}-*.gemspec")]
    if old_gemspecs.size > 0
      old_gemspecs.each {|spec| rm spec }
    end

    full_name = "#{gemspec.name}-#{gemspec.version}"

    gemspec.loaded_from = File.join srcdir, gemspec.spec_name

    package = RbInstall::DirPackage.new gemspec, {gemspec.bindir => 'libexec'}
    ins = RbInstall::UnpackedInstaller.new(package, options)
    puts "#{INDENT}#{gemspec.name} #{gemspec.version}"
    ins.install
  end
end

def mdoc_file?(mdoc)
  /^\.Nm / =~ File.read(mdoc, 1024)
end

# :startdoc:

install?(:local, :arch, :bin, :'bin-arch') do
  prepare "binary commands", (dest = archbindir || bindir)

  def (bins = []).add(name)
    push(name)
    name
  end

  install bins.add(ruby_install_name+exeext), dest, :mode => $prog_mode, :strip => $strip
  if rubyw_install_name and !rubyw_install_name.empty?
    install bins.add(rubyw_install_name+exeext), dest, :mode => $prog_mode, :strip => $strip
  end
  # emcc produces ruby and ruby.wasm, the first is a JavaScript file of runtime support
  # to load and execute the second .wasm file. Both are required to execute ruby
  if RUBY_PLATFORM =~ /emscripten/ and File.exist? ruby_install_name+".wasm"
    install bins.add(ruby_install_name+".wasm"), dest, :mode => $prog_mode, :strip => $strip
  end
  if File.exist? goruby_install_name+exeext
    install bins.add(goruby_install_name+exeext), dest, :mode => $prog_mode, :strip => $strip
  end
  if enable_shared and dll != lib
    install bins.add(dll), dest, :mode => $prog_mode, :strip => $strip
  end
  if archbindir
    prepare "binary command links", bindir
    relpath = Path.relative(archbindir, bindir)
    bins.each do |f|
      ln_sf(File.join(relpath, f), File.join(bindir, f))
    end
  end
end

install?(:local, :arch, :lib, :'lib-arch') do
  prepare "base libraries", libdir

  install lib, libdir, :mode => $prog_mode, :strip => $strip unless lib == arc
  install arc, libdir, :mode => $data_mode unless CONFIG["INSTALL_STATIC_LIBRARY"] == "no"
  if dll == lib and dll != arc
    for link in CONFIG["LIBRUBY_ALIASES"].split - [File.basename(dll)]
      ln_sf(dll, File.join(libdir, link))
    end
  end

  prepare "arch files", archlibdir
  install "rbconfig.rb", archlibdir, :mode => $data_mode
  if CONFIG["ARCHFILE"]
    for file in CONFIG["ARCHFILE"].split
      install file, archlibdir, :mode => $data_mode
    end
  end
end

install?(:local, :arch, :data) do
  pc = CONFIG["ruby_pc"]
  if pc and File.file?(pc) and File.size?(pc)
    prepare "pkgconfig data", pkgconfigdir = File.join(libdir, "pkgconfig")
    install pc, pkgconfigdir, :mode => $data_mode
    if (pkgconfig_base = CONFIG["libdir", true]) != libdir
      prepare "pkgconfig data link", File.join(pkgconfig_base, "pkgconfig")
      ln_sf(File.join("..", Path.relative(pkgconfigdir, pkgconfig_base), pc),
            File.join(pkgconfig_base, "pkgconfig", pc))
    end
  end
end

install?(:ext, :arch, :'ext-arch') do
  prepare "extension objects", archlibdir
  noinst = %w[-* -*/] | (CONFIG["no_install_files"] || "").split
  install_recursive("#{$extout}/#{CONFIG['arch']}", archlibdir, :no_install => noinst, :mode => $prog_mode, :strip => $strip)
  prepare "extension objects", sitearchlibdir
  prepare "extension objects", vendorarchlibdir
  if extso = File.read("exts.mk")[/^EXTSO[ \t]*=[ \t]*((?:.*\\\n)*.*)/, 1] and
    !(extso = extso.gsub(/\\\n/, '').split).empty?
    libpathenv = CONFIG["LIBPATHENV"]
    dest = CONFIG[!libpathenv || libpathenv == "PATH" ? "bindir" : "libdir"]
    prepare "external libraries", dest
    for file in extso
      install file, dest, :mode => $prog_mode
    end
  end
end

install?(:ext, :arch, :hdr, :'arch-hdr', :'hdr-arch') do
  prepare "extension headers", archhdrdir
  install_recursive("#{$extout}/include/#{CONFIG['arch']}", archhdrdir, :glob => "*.h", :mode => $data_mode)
end

install?(:ext, :comm, :'ext-comm') do
  prepare "extension scripts", rubylibdir
  install_recursive("#{$extout}/common", rubylibdir, :mode => $data_mode)
  prepare "extension scripts", sitelibdir
  prepare "extension scripts", vendorlibdir
end

install?(:ext, :comm, :hdr, :'comm-hdr', :'hdr-comm') do
  hdrdir = rubyhdrdir + "/ruby"
  prepare "extension headers", hdrdir
  install_recursive("#{$extout}/include/ruby", hdrdir, :glob => "*.h", :mode => $data_mode)
end

install?(:doc, :rdoc) do
  if $rdocdir
    ridatadir = File.join(CONFIG['ridir'], CONFIG['ruby_version'], "system")
    prepare "rdoc", ridatadir
    install_recursive($rdocdir, ridatadir, :no_install => rdoc_noinst, :mode => $data_mode)
  end
end

install?(:doc, :html) do
  if $htmldir
    prepare "html-docs", docdir
    install_recursive($htmldir, docdir+"/html", :no_install => rdoc_noinst, :mode => $data_mode)
  end
end

install?(:doc, :capi) do
  prepare "capi-docs", docdir
  install_recursive "doc/capi", docdir+"/capi", :mode => $data_mode
end

install?(:local, :comm, :bin, :'bin-comm') do
  prepare "command scripts", bindir

  install_recursive(File.join(srcdir, "bin"), bindir, :maxdepth => 1) do |src, cmd|
    $script_installer.install(src, cmd)
  end
end

install?(:local, :comm, :lib) do
  prepare "library scripts", rubylibdir
  noinst = %w[*.txt *.rdoc *.gemspec]
  install_recursive(File.join(srcdir, "lib"), rubylibdir, :no_install => noinst, :mode => $data_mode)
end

install?(:local, :comm, :hdr, :'comm-hdr') do
  prepare "common headers", rubyhdrdir

  noinst = []
  unless RUBY_PLATFORM =~ /mswin|mingw|bccwin/
    noinst << "win32.h"
  end
  noinst = nil if noinst.empty?
  install_recursive(File.join(srcdir, "include"), rubyhdrdir, :no_install => noinst, :glob => "*.{h,hpp}", :mode => $data_mode)
end

install?(:local, :comm, :man) do
  mdocs = Dir["#{srcdir}/man/*.[1-9]"]
  prepare "manpages", mandir, ([] | mdocs.collect {|mdoc| mdoc[/\d+$/]}).sort.collect {|sec| "man#{sec}"}

  mantype, suffix, compress = Compressors.for($mantype)
  mandir = File.join(mandir, "man")
  has_goruby = File.exist?(goruby_install_name+exeext)
  require File.join(srcdir, "tool/mdoc2man.rb") if /\Adoc\b/ !~ mantype
  mdocs.each do |mdoc|
    next unless File.file?(mdoc) and File.read(mdoc, 1) == '.'
    base = File.basename(mdoc)
    if base == "goruby.1"
      next unless has_goruby
    end

    destdir = mandir + (section = mdoc[/\d+$/])
    destname = ruby_install_name.sub(/ruby/, base.chomp(".#{section}"))
    destfile = File.join(destdir, "#{destname}.#{section}")

    if /\Adoc\b/ =~ mantype or !mdoc_file?(mdoc)
      if compress
        begin
          w = IO.popen(compress, "rb", in: mdoc, &:read)
        rescue
        else
          destfile << suffix
        end
      end
      if w
        open_for_install(destfile, $data_mode) {w}
      else
        install mdoc, destfile, :mode => $data_mode
      end
    else
      class << (w = [])
        alias print push
      end
      File.open(mdoc) {|r| Mdoc2Man.mdoc2man(r, w)}
      w = w.join("")
      if compress
        begin
          w = IO.popen(compress, "r+b") do |f|
            Thread.start {f.write w; f.close_write}
            f.read
          end
        rescue
        else
          destfile << suffix
        end
      end
      open_for_install(destfile, $data_mode) {w}
    end
  end
end

install?(:dbg, :nodefault) do
  prepare "debugger commands", bindir
  prepare "debugger scripts", rubylibdir
  conf = MAKEFILE_CONFIG.merge({"prefix"=>"${prefix#/}"})
  Dir.glob(File.join(srcdir, "template/ruby-*db.in")) do |src|
    cmd = $script_installer.transform(File.basename(src, ".in"))
    open_for_install(File.join(bindir, cmd), $script_mode) {
      RbConfig.expand(File.read(src), conf)
    }
  end
  Dir.glob(File.join(srcdir, "misc/lldb_*")) do |src|
    if File.directory?(src)
      install_recursive src, File.join(rubylibdir, File.basename(src))
    else
      install src, rubylibdir
    end
  end
  install File.join(srcdir, ".gdbinit"), File.join(rubylibdir, "gdbinit")
  if $debug_symbols
    {
      ruby_install_name => archbindir || bindir,
      rubyw_install_name => archbindir || bindir,
      goruby_install_name => archbindir || bindir,
      dll => libdir,
    }.each do |src, dest|
      next if src.empty?
      src += $debug_symbols
      if File.directory?(src)
        install_recursive src, File.join(dest, src)
      end
    end
  end
end

install?(:ext, :comm, :gem, :'default-gems', :'default-gems-comm') do
  install_default_gem('lib', srcdir, bindir)
end

install?(:ext, :arch, :gem, :'default-gems', :'default-gems-arch') do
  install_default_gem('ext', srcdir, bindir)
end

install?(:ext, :comm, :gem, :'bundled-gems') do
  gem_dir = Gem.default_dir
  install_dir = with_destdir(gem_dir)
  prepare "bundled gems", gem_dir
  RbInstall.no_write do
    # Record making directories
    makedirs(Gem.ensure_gem_subdirectories(install_dir, $dir_mode).map {|d| File.join(gem_dir, d)})
  end

  installed_gems = {}
  skipped = {}
  options = {
    :install_dir => install_dir,
    :bin_dir => with_destdir(bindir),
    :domain => :local,
    :ignore_dependencies => true,
    :dir_mode => $dir_mode,
    :data_mode => $data_mode,
    :prog_mode => $script_mode,
    :wrappers => true,
    :format_executable => true,
  }

  extensions_dir = Gem::StubSpecification.gemspec_stub("", gem_dir, gem_dir).extensions_dir
  specifications_dir = File.join(gem_dir, "specifications")
  build_dir = Gem::StubSpecification.gemspec_stub("", ".bundle", ".bundle").extensions_dir

  # We are about to build extensions, and want to configure extensions with the
  # newly installed ruby.
  Gem.instance_variable_set(:@ruby, with_destdir(File.join(bindir, ruby_install_name)))
  # Prevent fake.rb propagation. It conflicts with the natural mkmf configs of
  # the newly installed ruby.
  ENV.delete('RUBYOPT')

  collector = RbInstall::Specs::FileCollector::UnpackedGem
  File.foreach("#{srcdir}/gems/bundled_gems") do |name|
    next if /^\s*(?:#|$)/ =~ name
    next unless /^(\S+)\s+(\S+).*/ =~ name
    gem = $1
    gem_name = "#$1-#$2"
    path = [
      # gemspec that removed duplicated dependencies of bundled gems
      "#{srcdir}/.bundle/gems/#{gem_name}/#{gem}.gemspec",
      # gemspec for C ext gems, It has the original dependencies
      # ex .bundle/gems/debug-1.7.1/debug-1.7.1.gemspec
      "#{srcdir}/.bundle/gems/#{gem_name}/#{gem_name}.gemspec",
      # original gemspec generated by rubygems
      "#{srcdir}/.bundle/specifications/#{gem_name}.gemspec"
    ].find { |gemspec| File.exist?(gemspec) }
    if path.nil?
      skipped[gem_name] = "gemspec not found"
      next
    end
    base = "#{srcdir}/.bundle/gems/#{gem_name}"
    files = collector.new(path, base, nil).collect
    files.delete("#{gem}.gemspec")
    files.delete("#{gem_name}.gemspec")
    spec = load_gemspec(path, base, files: files)
    unless spec.platform == Gem::Platform::RUBY
      skipped[gem_name] = "not ruby platform (#{spec.platform})"
      next
    end
    unless spec.full_name == gem_name
      skipped[gem_name] = "full name unmatch #{spec.full_name}"
      next
    end
    # Skip install C ext bundled gem if it is build failed or not found
    if !spec.extensions.empty? && !File.exist?("#{build_dir}/#{gem_name}/gem.build_complete")
      skipped[gem_name] = "extensions not found or build failed #{spec.full_name}"
      next
    end
    spec.extension_dir = "#{extensions_dir}/#{spec.full_name}"

    package = RbInstall::DirPackage.new spec
    ins = RbInstall::UnpackedInstaller.new(package, options)
    puts "#{INDENT}#{spec.name} #{spec.version}"
    ins.install
    install_recursive("#{build_dir}/#{gem_name}", "#{extensions_dir}/#{gem_name}") do |src, dest|
      # puts "#{INDENT}    #{dest[extensions_dir.size+gem_name.size+2..-1]}"
      install src, dest, :mode => (File.executable?(src) ? $prog_mode : $data_mode)
    end
    installed_gems[spec.full_name] = true
  end
  installed_gems, gems = Dir.glob(srcdir+'/gems/*.gem').partition {|gem| installed_gems.key?(File.basename(gem, '.gem'))}
  unless installed_gems.empty?
    prepare "bundled gem cache", gem_dir+"/cache"
    install installed_gems, gem_dir+"/cache"
  end
  unless gems.empty?
    skipped.default = "not found in bundled_gems"
    puts "skipped bundled gems:"
    gems.each do |gem|
      gem = File.basename(gem)
      printf "    %-31s %s\n", gem, skipped[gem.chomp(".gem")]
    end
  end
end

install?('modular-gc') do
  if modular_gc_dir = CONFIG['modular_gc_dir'] and !modular_gc_dir.empty?
    dlext = CONFIG['DLEXT', true]
    modular_gc_dir = File.expand_path(modular_gc_dir, CONFIG['prefix'])
    prepare "modular GC library", modular_gc_dir
    install Dir.glob("gc/*/librubygc.*.#{dlext}"), modular_gc_dir
  end
end

parse_args()

include FileUtils
include FileUtils::NoWrite if $dryrun
@fileutils_output = STDOUT
@fileutils_label = ''

$install << :all if $install.empty?
installs = $install.map do |inst|
  if !(procs = $install_procs[inst]) || procs.empty?
    next warn("unknown install target - #{inst}")
  end
  procs
end
installs.flatten!
installs -= $exclude.map {|exc| $install_procs[exc]}.flatten
installs.each do |block|
  dir = Dir.pwd
  begin
    block.call
  ensure
    Dir.chdir(dir)
  end
end
unless installs.empty? or $destdir.empty?
  require_relative 'lib/colorize'
  puts "Installed under #{Colorize.new.info($destdir)}"
end

# vi:set sw=2:
