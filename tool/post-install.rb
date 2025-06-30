# frozen-string-literal: true

# Based on https://github.com/ruby/ruby-dev-builder/blob/master/cli_test.rb

require 'rbconfig'

module CLITest
  class << self
    BIN_DIR = RbConfig::CONFIG['bindir']
    RUBY_INSTALL_NAME = RbConfig::CONFIG["ruby_install_name"]
    abort unless RUBY_INSTALL_NAME.include?("ruby")

    EXECUTABLE_EXTS = RbConfig::CONFIG["EXECUTABLE_EXTS"].split(" ")
    EXECUTABLE_EXTS << "" if EXECUTABLE_EXTS.empty?

    ENV["PATH"] = [BIN_DIR, ENV["PATH"]].compact.join(File::PATH_SEPARATOR)

    DASH = "\u2500"
    PASSED = "\u{2705}"
    FAILED = "\u{274c}"

    # Returns the transformed executable name for +name+.
    def executable_name(name)
      "#{BIN_DIR}/#{RUBY_INSTALL_NAME.sub("ruby", name)}"
    end

    def chk_cli(cmd, regex)
      cmd_name, args = cmd.split(" ", 2)
      cmd_str = cmd_name.ljust(10)
      exec_name = executable_name(cmd_name)
      cmd = [exec_name, args].compact.join(" ")
      if EXECUTABLE_EXTS.any? {|ext| File.executable? exec_name+ext}
        ret = IO.popen(cmd, in: IO::NULL, err: IO::NULL, &:gets).chomp
        ret.sub!(exec_name, cmd_name)
        if ret[regex]
          "#{cmd_str}#{PASSED}   #{$1}"
        else
          @error += 1
          "#{cmd_str}#{FAILED}   version? (#{ret})"
        end
      else
        @error += 1
        "#{cmd_str}#{FAILED}   missing binstub"
      end
    rescue => e
      @error += 1
      "#{cmd_str}#{FAILED}   #{e.class}"
    end

    def run
      re_version = '(\d{1,2}\.\d{1,2}\.\d{1,2}(\.[a-z0-9.]+)?)'
      @error = 0
      puts '', "#{DASH * 5} CLI Test ".ljust(32, DASH)
      puts chk_cli("bundle -v",      /\ABundler version #{re_version}/)
      puts chk_cli("gem --version",  /\A#{re_version}/)
      puts chk_cli("irb --version",  /\Airb +#{re_version}/)
      puts chk_cli("racc --version", /\Aracc version #{re_version}/)
      puts chk_cli("rake -V", /\Arake, version #{re_version}/)
      puts chk_cli("rbs -v",  /\Arbs #{re_version}\z/)
      puts chk_cli("rdbg -v", /\Ardbg #{re_version}\z/)
      puts chk_cli("rdoc -v", /\A#{re_version}/)
      puts chk_cli("typeprof --version", /\Atypeprof #{re_version}/)
      puts ''

      cli_desc =  %x[#{RUBY_INSTALL_NAME} -v][/\A.*/]
      if cli_desc == RUBY_DESCRIPTION
        puts cli_desc, ''
      else
        puts "'ruby -v' doesn't match RUBY_DESCRIPTION\n" \
             "#{cli_desc}  (ruby -v)\n" \
             "#{RUBY_DESCRIPTION}  (RUBY_DESCRIPTION)", ''
        @error += 1
      end

      unless @error.zero?
        abort "bad exit"
      end
    end
  end
end

if $0 == __FILE__
  CLITest.run
end
