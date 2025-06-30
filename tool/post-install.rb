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
      exec_name = executable_name(cmd_name)
      cmd = [exec_name, args].compact.join(" ")
      if EXECUTABLE_EXTS.any? {|ext| File.executable? exec_name+ext}
        ret = IO.popen(cmd, in: IO::NULL, err: IO::NULL, &:gets).chomp
        ret.sub!(exec_name, cmd_name)
        if ret[regex]
          yield cmd_name, true, $1
        else
          @error += 1
          yield cmd_name, false, "version? (#{ret})"
        end
      else
        @error += 1
        yield cmd_name, false, "missing binstub"
      end
      return File.basename(exec_name)
    rescue => e
      @error += 1
      yield cmd_name, false, e.class
    end

    def run
      print = ->(cmd, succ, mesg) {
        printf "%-10s%s   %s\n", cmd, (succ ? PASSED : FAILED), mesg
      }
      re_version = '(\d{1,2}\.\d{1,2}\.\d{1,2}(\.[a-z0-9.]+)?)'
      @error = 0
      puts '', "#{DASH * 5} CLI Test ".ljust(32, DASH)
      bundle = chk_cli("bundle -v",      /\ABundler version #{re_version}/, &print)
      gem = chk_cli("gem --version",  /\A#{re_version}/, &print)
      irb = chk_cli("irb --version",  /\Airb +#{re_version}/, &print)
      racc = chk_cli("racc --version", /\Aracc version #{re_version}/, &print)
      rake = chk_cli("rake -V", /\Arake, version #{re_version}/, &print)
      rbs = chk_cli("rbs -v",  /\Arbs #{re_version}\z/, &print)
      rdbg = chk_cli("rdbg -v", /\Ardbg #{re_version}\z/, &print)
      rdoc = chk_cli("rdoc -v", /\A#{re_version}/, &print)
      typeprof = chk_cli("typeprof --version", /\Atypeprof #{re_version}/, &print)
      puts ''

      if @error.zero?
        dash_item = DASH * 7
        puts '', "#{DASH * 5} Run Tools ".ljust(32, DASH)
        require "tmpdir"
        Dir.mktmpdir do |dir|
          if bundle
            puts "#{dash_item} #{bundle}"
            File.write(dir + "/Gemfile", "")
            system(bundle, chdir: dir, exception: false) or @error += 1
          end
          if gem
            puts "#{dash_item} #{gem}"
            system(gem, "list", chdir: dir, exception: false) or @error += 1
          end
          if irb
            puts "#{dash_item} #{irb}"
            File.write(dir + "/irb_input", "IRB::VERSION\n")
            system(irb, "irb_input", chdir: dir, exception: false) or @error += 1
          end
          if racc
            puts "#{dash_item} #{racc}"
          end
          if rake
            puts "#{dash_item} #{rake}"
            File.write(dir + "/Rakefile", <<~RUBY)
            task :default => :version do
              puts 'OK'
            end
            task :version do
              print Rake::VERSION, " "
            end
            RUBY
            system(rake, chdir: dir, exception: false) or @error += 1
          end
          if rbs
            puts "#{dash_item} #{rbs}"
          end
          if rdbg
            puts "#{dash_item} #{rdbg}"
          end
          if rdoc
            puts "#{dash_item} #{rdoc}"
            File.write(dir + "/main.rb", <<~RUBY)
              # Class for test
              class Test
              end
            RUBY
            File.write(dir + "/.document", "main.rb\n")
            File.write(dir + "/.rdoc_options", <<~YAML)
              ---
              main_page: main.rb
            YAML
            system(rdoc, "-C", ".", chdir: dir, exception: false) or @error += 1
          end
          if typeprof
            puts "#{dash_item} #{typeprof}"
            File.write(dir + "/typeprof-target.rb", "p __FILE__\n")
            system(typeprof, "typeprof-target.rb", chdir: dir, exception: false) or @error += 1
          end
        end
      end

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
