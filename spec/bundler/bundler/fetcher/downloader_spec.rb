# frozen_string_literal: true

RSpec.describe Bundler::Fetcher::Downloader do
  let(:connection)     { double(:connection) }
  let(:redirect_limit) { 5 }
  let(:uri)            { Gem::URI("http://www.uri-to-fetch.com/api/v2/endpoint") }
  let(:options)        { double(:options) }

  subject { described_class.new(connection, redirect_limit) }

  describe "fetch" do
    let(:counter)      { 0 }
    let(:httpv)        { "1.1" }
    let(:http_response) { double(:response) }

    before do
      allow(subject).to receive(:request).with(uri, options).and_return(http_response)
      allow(http_response).to receive(:body).and_return("Body with info")
    end

    context "when the # requests counter is greater than the redirect limit" do
      let(:counter) { redirect_limit + 1 }

      it "should raise a Bundler::HTTPError specifying too many redirects" do
        expect { subject.fetch(uri, options, counter) }.to raise_error(Bundler::HTTPError, "Too many redirects")
      end
    end

    context "logging" do
      let(:http_response) { Gem::Net::HTTPSuccess.new("1.1", 200, "Success") }

      it "should log the HTTP response code and message to debug" do
        expect(Bundler).to receive_message_chain(:ui, :debug).with("HTTP 200 Success #{uri}")
        subject.fetch(uri, options, counter)
      end
    end

    context "when the request response is a Gem::Net::HTTPRedirection" do
      let(:http_response) { Gem::Net::HTTPRedirection.new(httpv, 308, "Moved") }

      before { http_response["location"] = "http://www.redirect-uri.com/api/v2/endpoint" }

      it "should try to fetch the redirect uri and iterate the # requests counter" do
        expect(subject).to receive(:fetch).with(Gem::URI("http://www.uri-to-fetch.com/api/v2/endpoint"), options, 0).and_call_original
        expect(subject).to receive(:fetch).with(Gem::URI("http://www.redirect-uri.com/api/v2/endpoint"), options, 1)
        subject.fetch(uri, options, counter)
      end

      context "when the redirect uri and original uri are the same" do
        let(:uri) { Gem::URI("ssh://username:password@www.uri-to-fetch.com/api/v2/endpoint") }

        before { http_response["location"] = "ssh://www.uri-to-fetch.com/api/v1/endpoint" }

        it "should set the same user and password for the redirect uri" do
          expect(subject).to receive(:fetch).with(Gem::URI("ssh://username:password@www.uri-to-fetch.com/api/v2/endpoint"), options, 0).and_call_original
          expect(subject).to receive(:fetch).with(Gem::URI("ssh://username:password@www.uri-to-fetch.com/api/v1/endpoint"), options, 1)
          subject.fetch(uri, options, counter)
        end
      end
    end

    context "when the request response is a Gem::Net::HTTPSuccess" do
      let(:http_response) { Gem::Net::HTTPSuccess.new("1.1", 200, "Success") }

      it "should return the response body" do
        expect(subject.fetch(uri, options, counter)).to eq(http_response)
      end
    end

    context "when the request response is a Gem::Net::HTTPRequestEntityTooLarge" do
      let(:http_response) { Gem::Net::HTTPRequestEntityTooLarge.new("1.1", 413, "Too Big") }

      it "should raise a Bundler::Fetcher::FallbackError with the response body" do
        expect { subject.fetch(uri, options, counter) }.to raise_error(Bundler::Fetcher::FallbackError, "Body with info")
      end
    end

    context "when the request response is a Gem::Net::HTTPUnauthorized" do
      let(:http_response) { Gem::Net::HTTPUnauthorized.new("1.1", 401, "Unauthorized") }

      it "should raise a Bundler::Fetcher::AuthenticationRequiredError with the uri host" do
        expect { subject.fetch(uri, options, counter) }.to raise_error(Bundler::Fetcher::AuthenticationRequiredError,
          /Authentication is required for www.uri-to-fetch.com/)
      end

      it "should raise a Bundler::Fetcher::AuthenticationRequiredError with advice" do
        expect { subject.fetch(uri, options, counter) }.to raise_error(Bundler::Fetcher::AuthenticationRequiredError,
          /`bundle config set --global www\.uri-to-fetch\.com username:password`.*`BUNDLE_WWW__URI___TO___FETCH__COM`/m)
      end

      context "when there are credentials provided in the request" do
        let(:uri) { Gem::URI("http://user:password@www.uri-to-fetch.com") }

        it "should raise a Bundler::Fetcher::BadAuthenticationError that doesn't contain the password" do
          expect { subject.fetch(uri, options, counter) }.
            to raise_error(Bundler::Fetcher::BadAuthenticationError, /Bad username or password for www.uri-to-fetch.com/)
        end
      end
    end

    context "when the request response is a Gem::Net::HTTPForbidden" do
      let(:http_response) { Gem::Net::HTTPForbidden.new("1.1", 403, "Forbidden") }
      let(:uri) { Gem::URI("http://user:password@www.uri-to-fetch.com") }

      it "should raise a Bundler::Fetcher::AuthenticationForbiddenError with the uri host" do
        expect { subject.fetch(uri, options, counter) }.to raise_error(Bundler::Fetcher::AuthenticationForbiddenError,
          /Access token could not be authenticated for www.uri-to-fetch.com/)
      end
    end

    context "when the request response is a Gem::Net::HTTPNotFound" do
      let(:http_response) { Gem::Net::HTTPNotFound.new("1.1", 404, "Not Found") }

      it "should raise a Bundler::Fetcher::FallbackError with Gem::Net::HTTPNotFound" do
        expect { subject.fetch(uri, options, counter) }.
          to raise_error(Bundler::Fetcher::FallbackError, "Gem::Net::HTTPNotFound: http://www.uri-to-fetch.com/api/v2/endpoint")
      end

      context "when there are credentials provided in the request" do
        let(:uri) { Gem::URI("http://username:password@www.uri-to-fetch.com/api/v2/endpoint") }

        it "should raise a Bundler::Fetcher::FallbackError that doesn't contain the password" do
          expect { subject.fetch(uri, options, counter) }.
            to raise_error(Bundler::Fetcher::FallbackError, "Gem::Net::HTTPNotFound: http://username@www.uri-to-fetch.com/api/v2/endpoint")
        end
      end
    end

    context "when the request response is some other type" do
      let(:http_response) { Gem::Net::HTTPBadGateway.new("1.1", 500, "Fatal Error") }

      it "should raise a Bundler::HTTPError with the response class and body" do
        expect { subject.fetch(uri, options, counter) }.to raise_error(Bundler::HTTPError, "Gem::Net::HTTPBadGateway: Body with info")
      end
    end
  end

  describe "request" do
    let(:net_http_get) { double(:net_http_get) }
    let(:response)     { double(:response) }

    before do
      allow(Gem::Net::HTTP::Get).to receive(:new).with("/api/v2/endpoint", options).and_return(net_http_get)
      allow(connection).to receive(:request).with(uri, net_http_get).and_return(response)
    end

    it "should log the HTTP GET request to debug" do
      expect(Bundler).to receive_message_chain(:ui, :debug).with("HTTP GET http://www.uri-to-fetch.com/api/v2/endpoint")
      subject.request(uri, options)
    end

    context "when there is a user provided in the request" do
      context "and there is also a password provided" do
        context "that contains cgi escaped characters" do
          let(:uri) { Gem::URI("http://username:password%24@www.uri-to-fetch.com/api/v2/endpoint") }

          it "should request basic authentication with the username and password, and log the HTTP GET request to debug, without the password" do
            expect(net_http_get).to receive(:basic_auth).with("username", "password$")
            expect(Bundler).to receive_message_chain(:ui, :debug).with("HTTP GET http://username@www.uri-to-fetch.com/api/v2/endpoint")
            subject.request(uri, options)
          end
        end

        context "that is all unescaped characters" do
          let(:uri) { Gem::URI("http://username:password@www.uri-to-fetch.com/api/v2/endpoint") }
          it "should request basic authentication with the username and proper cgi compliant password, and log the HTTP GET request to debug, without the password" do
            expect(net_http_get).to receive(:basic_auth).with("username", "password")
            expect(Bundler).to receive_message_chain(:ui, :debug).with("HTTP GET http://username@www.uri-to-fetch.com/api/v2/endpoint")
            subject.request(uri, options)
          end
        end
      end

      context "and it's used as the authentication token" do
        let(:uri) { Gem::URI("http://username@www.uri-to-fetch.com/api/v2/endpoint") }

        it "should request basic authentication with just the user, and log the HTTP GET request to debug, without the token" do
          expect(net_http_get).to receive(:basic_auth).with("username", nil)
          expect(Bundler).to receive_message_chain(:ui, :debug).with("HTTP GET http://www.uri-to-fetch.com/api/v2/endpoint")
          subject.request(uri, options)
        end
      end

      context "and it's used as the authentication token, and contains cgi escaped characters" do
        let(:uri) { Gem::URI("http://username%24@www.uri-to-fetch.com/api/v2/endpoint") }

        it "should request basic authentication with the proper cgi compliant password user, and log the HTTP GET request to debug, without the token" do
          expect(net_http_get).to receive(:basic_auth).with("username$", nil)
          expect(Bundler).to receive_message_chain(:ui, :debug).with("HTTP GET http://www.uri-to-fetch.com/api/v2/endpoint")
          subject.request(uri, options)
        end
      end
    end

    context "when the request response causes a OpenSSL::SSL::SSLError" do
      before { allow(connection).to receive(:request).with(uri, net_http_get) { raise OpenSSL::SSL::SSLError.new } }

      it "should raise a LoadError about openssl" do
        expect { subject.request(uri, options) }.to raise_error(Bundler::Fetcher::CertificateFailureError,
          %r{Could not verify the SSL certificate for http://www.uri-to-fetch.com/api/v2/endpoint})
      end
    end

    context "when the request response causes an HTTP error" do
      let(:message) { "error about network" }
      let(:error) { error_class.new(message) }

      before do
        allow(connection).to receive(:request).with(uri, net_http_get) { raise error }
      end

      context "that it's retryable" do
        let(:error_class) { Gem::Timeout::Error }

        it "should trace log the error" do
          allow(Bundler).to receive_message_chain(:ui, :debug)
          expect(Bundler).to receive_message_chain(:ui, :trace).with(error)
          expect { subject.request(uri, options) }.to raise_error(Bundler::HTTPError)
        end

        it "should raise a Bundler::HTTPError" do
          expect { subject.request(uri, options) }.to raise_error(Bundler::HTTPError,
            "Network error while fetching http://www.uri-to-fetch.com/api/v2/endpoint (error about network)")
        end

        context "when there are credentials provided in the request" do
          let(:uri) { Gem::URI("http://username:password@www.uri-to-fetch.com/api/v2/endpoint") }
          before do
            allow(net_http_get).to receive(:basic_auth).with("username", "password")
          end

          it "should raise a Bundler::HTTPError that doesn't contain the password" do
            expect { subject.request(uri, options) }.to raise_error(Bundler::HTTPError,
              "Network error while fetching http://username@www.uri-to-fetch.com/api/v2/endpoint (error about network)")
          end
        end
      end

      context "when error is about the host being down" do
        let(:error_class) { Gem::Net::HTTP::Persistent::Error }
        let(:message) { "host down: http://www.uri-to-fetch.com" }

        it "should raise a Bundler::Fetcher::NetworkDownError" do
          expect { subject.request(uri, options) }.to raise_error(Bundler::Fetcher::NetworkDownError,
            /Could not reach host www.uri-to-fetch.com/)
        end
      end

      context "when error is about connection refused" do
        let(:error_class) { Gem::Net::HTTP::Persistent::Error }
        let(:message) { "connection refused down: http://www.uri-to-fetch.com" }

        it "should raise a Bundler::Fetcher::NetworkDownError" do
          expect { subject.request(uri, options) }.to raise_error(Bundler::Fetcher::NetworkDownError,
            /Could not reach host www.uri-to-fetch.com/)
        end
      end

      context "when error is about no route to host" do
        let(:error_class) { SocketError }
        let(:message) { "Failed to open TCP connection to www.uri-to-fetch.com:443 " }

        it "should raise a Bundler::Fetcher::NetworkDownError" do
          expect { subject.request(uri, options) }.to raise_error(Bundler::Fetcher::NetworkDownError,
            /Could not reach host www.uri-to-fetch.com/)
        end
      end
    end
  end
end
