# frozen_string_literal: true
begin
  require "openssl"
rescue LoadError
end

require "test/unit"
require "core_assertions"
require "tempfile"
require "socket"

if defined?(OpenSSL)

module OpenSSL::TestUtils
  module Fixtures
    module_function

    def pkey(name)
      OpenSSL::PKey.read(read_file("pkey", name))
    end

    def read_file(category, name)
      @file_cache ||= {}
      @file_cache[[category, name]] ||=
        File.read(File.join(__dir__, "fixtures", category, name + ".pem"))
    end
  end

  module_function

  def generate_cert(dn, key, serial, issuer,
                    not_before: nil, not_after: nil)
    cert = OpenSSL::X509::Certificate.new
    issuer = cert unless issuer
    cert.version = 2
    cert.serial = serial
    cert.subject = dn
    cert.issuer = issuer.subject
    cert.public_key = key
    now = Time.now
    cert.not_before = not_before || now - 3600
    cert.not_after = not_after || now + 3600
    cert
  end


  def issue_cert(dn, key, serial, extensions, issuer, issuer_key,
                 not_before: nil, not_after: nil, digest: "sha256")
    cert = generate_cert(dn, key, serial, issuer,
                         not_before: not_before, not_after: not_after)
    issuer = cert unless issuer
    issuer_key = key unless issuer_key
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = issuer
    extensions.each{|oid, value, critical|
      cert.add_extension(ef.create_extension(oid, value, critical))
    }
    cert.sign(issuer_key, digest)
    cert
  end

  def issue_crl(revoke_info, serial, lastup, nextup, extensions,
                issuer, issuer_key, digest)
    crl = OpenSSL::X509::CRL.new
    crl.issuer = issuer.subject
    crl.version = 1
    crl.last_update = lastup
    crl.next_update = nextup
    revoke_info.each{|rserial, time, reason_code|
      revoked = OpenSSL::X509::Revoked.new
      revoked.serial = rserial
      revoked.time = time
      enum = OpenSSL::ASN1::Enumerated(reason_code)
      ext = OpenSSL::X509::Extension.new("CRLReason", enum)
      revoked.add_extension(ext)
      crl.add_revoked(revoked)
    }
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.issuer_certificate = issuer
    ef.crl = crl
    crlnum = OpenSSL::ASN1::Integer(serial)
    crl.add_extension(OpenSSL::X509::Extension.new("crlNumber", crlnum))
    extensions.each{|oid, value, critical|
      crl.add_extension(ef.create_extension(oid, value, critical))
    }
    crl.sign(issuer_key, digest)
    crl
  end

  def get_subject_key_id(cert, hex: true)
    asn1_cert = OpenSSL::ASN1.decode(cert)
    tbscert   = asn1_cert.value[0]
    pkinfo    = tbscert.value[6]
    publickey = pkinfo.value[1]
    pkvalue   = publickey.value
    digest = OpenSSL::Digest.digest('SHA1', pkvalue)
    if hex
      digest.unpack("H2"*20).join(":").upcase
    else
      digest
    end
  end

  def openssl?(major = nil, minor = nil, fix = nil, patch = 0, status = 0)
    return false if OpenSSL::OPENSSL_VERSION.include?("LibreSSL") || OpenSSL::OPENSSL_VERSION.include?("AWS-LC")
    return true unless major
    OpenSSL::OPENSSL_VERSION_NUMBER >=
      major * 0x10000000 + minor * 0x100000 + fix * 0x1000 + patch * 0x10 +
      status * 0x1
  end

  def libressl?(major = nil, minor = nil, fix = nil)
    version = OpenSSL::OPENSSL_VERSION.scan(/LibreSSL (\d+)\.(\d+)\.(\d+).*/)[0]
    return false unless version
    !major || (version.map(&:to_i) <=> [major, minor, fix]) >= 0
  end

  def aws_lc?
    OpenSSL::OPENSSL_VERSION.include?("AWS-LC")
  end
end

class OpenSSL::TestCase < Test::Unit::TestCase
  include OpenSSL::TestUtils
  extend OpenSSL::TestUtils
  include Test::Unit::CoreAssertions

  def setup
    if ENV["OSSL_GC_STRESS"] == "1"
      GC.stress = true
    end
  end

  def teardown
    if ENV["OSSL_GC_STRESS"] == "1"
      GC.stress = false
    end
    # OpenSSL error stack must be empty
    assert_equal([], OpenSSL.errors)
  end

  # Omit the tests in FIPS.
  #
  # For example, the password based encryption used in the PEM format uses MD5
  # for deriving the encryption key from the password, and MD5 is not
  # FIPS-approved.
  #
  # See https://github.com/openssl/openssl/discussions/21830#discussioncomment-6865636
  # for details.
  def omit_on_fips
    return unless OpenSSL.fips_mode

    omit <<~MESSAGE
      Only for OpenSSL non-FIPS with the following possible reasons:
      * A testing logic is non-FIPS specific.
      * An encryption used in the test is not FIPS-approved.
    MESSAGE
  end

  def omit_on_non_fips
    return if OpenSSL.fips_mode

    omit "Only for OpenSSL FIPS"
  end
end

class OpenSSL::SSLTestCase < OpenSSL::TestCase
  RUBY = EnvUtil.rubybin
  ITERATIONS = ($0 == __FILE__) ? 100 : 10

  def setup
    super
    @ca_key  = Fixtures.pkey("rsa-1")
    @svr_key = Fixtures.pkey("rsa-2")
    @cli_key = Fixtures.pkey("rsa-3")
    @ca  = OpenSSL::X509::Name.parse("/DC=org/DC=ruby-lang/CN=CA")
    @svr = OpenSSL::X509::Name.parse("/DC=org/DC=ruby-lang/CN=localhost")
    @cli = OpenSSL::X509::Name.parse("/DC=org/DC=ruby-lang/CN=localhost")
    @ca_exts = [
      ["basicConstraints","CA:TRUE",true],
      ["keyUsage","cRLSign,keyCertSign",true],
    ]
    @ee_exts = [
      ["keyUsage","keyEncipherment,digitalSignature",true],
    ]
    @ca_cert  = issue_cert(@ca, @ca_key, 1, @ca_exts, nil, nil)
    @svr_cert = issue_cert(@svr, @svr_key, 2, @ee_exts, @ca_cert, @ca_key)
    @cli_cert = issue_cert(@cli, @cli_key, 3, @ee_exts, @ca_cert, @ca_key)
    @server = nil
  end

  def readwrite_loop(ctx, ssl)
    while line = ssl.gets
      ssl.write(line)
    end
  end

  def start_server(verify_mode: OpenSSL::SSL::VERIFY_NONE,
                   ctx_proc: nil, server_proc: method(:readwrite_loop),
                   accept_proc: proc{},
                   ignore_listener_error: false, &block)
    IO.pipe {|stop_pipe_r, stop_pipe_w|
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.cert = @svr_cert
      ctx.key = @svr_key
      ctx.verify_mode = verify_mode
      ctx_proc.call(ctx) if ctx_proc

      Socket.do_not_reverse_lookup = true
      tcps = TCPServer.new("127.0.0.1", 0)
      port = tcps.connect_address.ip_port

      ssls = OpenSSL::SSL::SSLServer.new(tcps, ctx)

      threads = []
      begin
        server_thread = Thread.new do
          Thread.current.report_on_exception = false

          begin
            loop do
              begin
                readable, = IO.select([ssls, stop_pipe_r])
                break if readable.include? stop_pipe_r
                ssl = ssls.accept
                accept_proc.call(ssl)
              rescue OpenSSL::SSL::SSLError, IOError, Errno::EBADF, Errno::EINVAL,
                     Errno::ECONNABORTED, Errno::ENOTSOCK, Errno::ECONNRESET
                retry if ignore_listener_error
                raise
              end

              th = Thread.new do
                Thread.current.report_on_exception = false

                begin
                  server_proc.call(ctx, ssl)
                ensure
                  ssl.close
                end
                true
              end
              threads << th
            end
          ensure
            tcps.close
          end
        end

        client_thread = Thread.new do
          Thread.current.report_on_exception = false

          begin
            block.call(port)
          ensure
            # Stop accepting new connection
            stop_pipe_w.close
            server_thread.join
          end
        end
        threads.unshift client_thread
      ensure
        # Terminate existing connections. If a thread did 'pend', re-raise it.
        pend = nil
        threads.each { |th|
          begin
            timeout = EnvUtil.apply_timeout_scale(30)
            th.join(timeout) or
              th.raise(RuntimeError, "[start_server] thread did not exit in #{timeout} secs")
          rescue Test::Unit::PendedError
            pend = $!
          rescue Exception
          end
        }
        raise pend if pend
        assert_join_threads(threads)
      end
    }
  end
end

class OpenSSL::PKeyTestCase < OpenSSL::TestCase
  def check_component(base, test, keys)
    keys.each { |comp|
      assert_equal base.send(comp), test.send(comp)
    }
  end

  def assert_sign_verify_false_or_error
    ret = yield
  rescue => e
    assert_kind_of(OpenSSL::PKey::PKeyError, e)
  else
    assert_equal(false, ret)
  end
end

module OpenSSL::Certs
  include OpenSSL::TestUtils

  module_function

  def ca_cert
    ca = OpenSSL::X509::Name.parse("/DC=org/DC=ruby-lang/CN=Timestamp Root CA")

    ca_exts = [
      ["basicConstraints","CA:TRUE,pathlen:1",true],
      ["keyUsage","keyCertSign, cRLSign",true],
      ["subjectKeyIdentifier","hash",false],
      ["authorityKeyIdentifier","keyid:always",false],
    ]
    OpenSSL::TestUtils.issue_cert(ca, Fixtures.pkey("rsa2048"), 1, ca_exts, nil, nil)
  end

  def ts_cert_direct(key, ca_cert)
    dn = OpenSSL::X509::Name.parse("/DC=org/DC=ruby-lang/OU=Timestamp/CN=Server Direct")

    exts = [
      ["basicConstraints","CA:FALSE",true],
      ["keyUsage","digitalSignature, nonRepudiation", true],
      ["subjectKeyIdentifier", "hash",false],
      ["authorityKeyIdentifier","keyid,issuer", false],
      ["extendedKeyUsage", "timeStamping", true]
    ]

    OpenSSL::TestUtils.issue_cert(dn, key, 2, exts, ca_cert, Fixtures.pkey("rsa2048"))
  end

  def intermediate_cert(key, ca_cert)
    dn = OpenSSL::X509::Name.parse("/DC=org/DC=ruby-lang/OU=Timestamp/CN=Timestamp Intermediate CA")

    exts = [
      ["basicConstraints","CA:TRUE,pathlen:0",true],
      ["keyUsage","keyCertSign, cRLSign",true],
      ["subjectKeyIdentifier","hash",false],
      ["authorityKeyIdentifier","keyid:always",false],
    ]

    OpenSSL::TestUtils.issue_cert(dn, key, 3, exts, ca_cert, Fixtures.pkey("rsa2048"))
  end

  def ts_cert_ee(key, intermediate, im_key)
    dn = OpenSSL::X509::Name.parse("/DC=org/DC=ruby-lang/OU=Timestamp/CN=Server End Entity")

    exts = [
      ["keyUsage","digitalSignature, nonRepudiation", true],
      ["subjectKeyIdentifier", "hash",false],
      ["authorityKeyIdentifier","keyid,issuer", false],
      ["extendedKeyUsage", "timeStamping", true]
    ]

    OpenSSL::TestUtils.issue_cert(dn, key, 4, exts, intermediate, im_key)
  end
end

end
