require_relative '../test_helper'

describe Rack::Prerendercloud do

  bot = 'Baiduspider+(+http://www.baidu.com/search/spider.htm)'
  user = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.76 Safari/537.36'

  before :each do
    @app = lambda do |params|
      [200, {}, ""]
    end

    @prerender = Rack::Prerendercloud.new(@app)
  end


  it "should preserve status code and location header" do
    request = Rack::MockRequest.env_for "/", "HTTP_USER_AGENT" => bot
    stub_request(:get, @prerender.build_api_url(request)).with(:headers => { 'User-Agent' => bot }).to_return(:body => "<html></html>", :status => 301, :headers => { 'Location' => 'http://google.com'})
    response = Rack::Prerendercloud.new(@app).call(request)

    assert_equal response[2].body, ["<html></html>"]
    assert_equal response[2].status, 301
    assert_equal( { 'location' => 'http://google.com', 'Content-Length' => '13'}, response[2].headers )
  end


  it "should return a prerendered reponse if user is a bot by checking for _escaped_fragment_" do
    request = Rack::MockRequest.env_for "/path?_escaped_fragment_=", "HTTP_USER_AGENT" => user
    stub_request(:get, @prerender.build_api_url(request)).with(:headers => { 'User-Agent' => user }).to_return(:body => "<html></html>")
    response = Rack::Prerendercloud.new(@app).call(request)

    assert_equal ["<html></html>"], response[2].body
  end

  it "should return a prerendered reponse if the url is for .html file" do
    request = Rack::MockRequest.env_for "/path.html", "HTTP_USER_AGENT" => bot
    stub_request(:get, @prerender.build_api_url(request)).with(:headers => { 'User-Agent' => bot }).to_return(:body => "<html></html>")
    response = Rack::Prerendercloud.new(@app).call(request)

    assert_equal ["<html></html>"], response[2].body
  end

  it "should continue to app routes if the url is for .js file" do
    request = Rack::MockRequest.env_for "/path.js", "HTTP_USER_AGENT" => bot
    stub_request(:get, @prerender.build_api_url(request)).with(:headers => { 'User-Agent' => bot }).to_return(:body => "<html></html>")
    response = Rack::Prerendercloud.new(@app).call(request)

    assert_equal "", response[2]
  end

  it "with bots_only, should continue to app routes if the url is a bad url with _escaped_fragment_" do
    request = Rack::MockRequest.env_for "/path?query=string?_escaped_fragment_=", "HTTP_USER_AGENT" => user
    response = Rack::Prerendercloud.new(@app, bots_only: true).call(request)

    assert_equal "", response[2]
  end


  it "should continue to app routes if the request is not a GET" do
    request = Rack::MockRequest.env_for "/path?_escaped_fragment_=", { "HTTP_USER_AGENT" => user, "REQUEST_METHOD" => "POST" }
    response = Rack::Prerendercloud.new(@app).call(request)

    assert_equal "", response[2]
  end


  it "with bots_only option, should continue to app routes if user is not a bot by checking agent string" do
    request = Rack::MockRequest.env_for "/", "HTTP_USER_AGENT" => user
    response = Rack::Prerendercloud.new(@app, bots_only: true).call(request)

    assert_equal "", response[2]
  end


  it "should continue to app routes if prerendercloud user-agent" do
    request = Rack::MockRequest.env_for "/path?_escaped_fragment_=", "HTTP_USER_AGENT" => 'prerendercloud'
    response = Rack::Prerendercloud.new(@app).call(request)

    assert_equal "", response[2]
  end


  it "should continue to app routes if user is a bot, but the bot is requesting a resource file" do
    request = Rack::MockRequest.env_for "/main.js?anyQueryParam=true", "HTTP_USER_AGENT" => bot
    response = Rack::Prerendercloud.new(@app).call(request)

    assert_equal "", response[2]
  end


  it "should set use_ssl to true for https prerender_service_url" do
    @prerender = Rack::Prerendercloud.new(@app, prerender_service_url: 'https://service.prerender.cloud/')

    request = Rack::MockRequest.env_for "/search/things/123/page?_escaped_fragment_=", "HTTP_USER_AGENT" => bot
    stub_request(:get, @prerender.build_api_url(request)).to_return(:body => "<html></html>")
    response = @prerender.call(request)

    assert_equal ["<html></html>"], response[2].body
  end


  it "should continue to app routes if the url is not part of the regex specific whitelist" do
    request = Rack::MockRequest.env_for "/saved/search/blah?_escaped_fragment_=", "HTTP_USER_AGENT" => bot
    response = Rack::Prerendercloud.new(@app, whitelist: [/^\/search/, '/help']).call(request)

    assert_equal "", response[2]
  end


  it "should return a prerendered response if the url is part of the regex specific whitelist" do
    request = Rack::MockRequest.env_for "/search/things/123/page?_escaped_fragment_=", "HTTP_USER_AGENT" => bot
    stub_request(:get, @prerender.build_api_url(request)).to_return(:body => "<html></html>")
    response = Rack::Prerendercloud.new(@app, whitelist: [/^\/search.*page/, '/help']).call(request)

    assert_equal ["<html></html>"], response[2].body
  end


  it "should continue to app routes if the url is part of the regex specific blacklist" do
    request = Rack::MockRequest.env_for "/search/things/123/page", "HTTP_USER_AGENT" => bot
    response = Rack::Prerendercloud.new(@app, blacklist: [/^\/search/, '/help']).call(request)

    assert_equal "", response[2]
  end

  it "should continue to app routes if the hashbang url is part of the regex specific blacklist" do
    request = Rack::MockRequest.env_for "?_escaped_fragment_=/search/things/123/page", "HTTP_USER_AGENT" => bot
    response = Rack::Prerendercloud.new(@app, blacklist: [/\/search/, '/help']).call(request)

    assert_equal "", response[2]
  end

  it "should return a prerendered response if the url is not part of the regex specific blacklist" do
    request = Rack::MockRequest.env_for "/profile/search/blah", "HTTP_USER_AGENT" => bot
    stub_request(:get, @prerender.build_api_url(request)).to_return(:body => "<html></html>")
    response = Rack::Prerendercloud.new(@app, blacklist: [/^\/search/, '/help']).call(request)

    assert_equal ["<html></html>"], response[2].body
  end


  it "should continue to app routes if the referer is part of the regex specific blacklist (regex match)" do
    request = Rack::MockRequest.env_for "/api/results", "HTTP_USER_AGENT" => bot, "HTTP_REFERER" => '/search'
    response = Rack::Prerendercloud.new(@app, blacklist: [/^\/search/, '/help']).call(request)

    assert_equal "", response[2]
  end

  it "should continue to app routes if the referer is part of the regex specific blacklist (string match)" do
    request = Rack::MockRequest.env_for "/api/results", "HTTP_USER_AGENT" => bot, "HTTP_REFERER" => '/search'
    response = Rack::Prerendercloud.new(@app, blacklist: ['/search', '/help']).call(request)

    assert_equal "", response[2]
  end

  it "should return a prerendered response if the referer is not part of the regex specific blacklist" do
    request = Rack::MockRequest.env_for "/api/results", "HTTP_USER_AGENT" => bot, "HTTP_REFERER" => '/profile/search'
    stub_request(:get, @prerender.build_api_url(request)).to_return(:body => "<html></html>")
    response = Rack::Prerendercloud.new(@app, blacklist: [/^\/search/, '/help']).call(request)

    assert_equal ["<html></html>"], response[2].body
  end


  it "should return a prerendered response if a string is returned from before_render" do
    request = Rack::MockRequest.env_for "/", "HTTP_USER_AGENT" => bot
    response = Rack::Prerendercloud.new(@app, before_render: Proc.new do |env| '<html>cached</html>' end).call(request)

    assert_equal ["<html>cached</html>"], response[2].body
  end


  it "should return a prerendered response if a response is returned from before_render" do
    request = Rack::MockRequest.env_for "/", "HTTP_USER_AGENT" => bot
    response = Rack::Prerendercloud.new(@app, before_render: Proc.new do |env| Rack::Response.new('<html>cached2</html>', 200, { 'test' => 'test2Header'}) end).call(request)

    assert_equal ["<html>cached2</html>"], response[2].body
    assert_equal response[2].status, 200
    assert_equal( { 'test' => 'test2Header', "Content-Length"=>"20"}, response[2].headers )
  end


  describe '#buildApiUrl' do
    it "should build the correct api url with the default url" do
      request = Rack::MockRequest.env_for "https://google.com/search?q=javascript"
      ENV['PRERENDER_SERVICE_URL'] = nil
      assert_equal 'http://service.prerender.cloud/https://google.com/search?q=javascript', @prerender.build_api_url(request)
    end


    it "should build the correct api url with an environment variable url" do
      ENV['PRERENDER_SERVICE_URL'] = 'http://prerenderurl.com'
      request = Rack::MockRequest.env_for "https://google.com/search?q=javascript"
      assert_equal 'http://prerenderurl.com/https://google.com/search?q=javascript', @prerender.build_api_url(request)
      ENV['PRERENDER_SERVICE_URL'] = nil
    end


    it "should build the correct api url with an initialization variable url" do
      @prerender = Rack::Prerendercloud.new(@app, prerender_service_url: 'http://prerenderurl.com')
      request = Rack::MockRequest.env_for "https://google.com/search?q=javascript"
      assert_equal 'http://prerenderurl.com/https://google.com/search?q=javascript', @prerender.build_api_url(request)
    end


    it "should build the correct https api url with an initialization variable url" do
      @prerender = Rack::Prerendercloud.new(@app, prerender_service_url: 'https://prerenderurl.com')
      request = Rack::MockRequest.env_for "https://google.com/search?q=javascript"
      assert_equal 'https://prerenderurl.com/https://google.com/search?q=javascript', @prerender.build_api_url(request)
    end


    # Check CF-Visitor header in order to Work behind CloudFlare with Flexible SSL (https://support.cloudflare.com/hc/en-us/articles/200170536)
    it "should build the correct api url for the Cloudflare Flexible SSL support" do
      request = Rack::MockRequest.env_for "http://google.com/search?q=javascript", { 'CF-VISITOR' => '"scheme":"https"'}
      ENV['PRERENDER_SERVICE_URL'] = nil
      assert_equal 'http://service.prerender.cloud/https://google.com/search?q=javascript', @prerender.build_api_url(request)
    end


    # Check X-Forwarded-Proto because Heroku SSL Support terminates at the load balancer
    it "should build the correct api url for the Heroku SSL Addon support with single value" do
      request = Rack::MockRequest.env_for "http://google.com/search?q=javascript", { 'X-FORWARDED-PROTO' => 'https'}
      ENV['PRERENDER_SERVICE_URL'] = nil
      assert_equal 'http://service.prerender.cloud/https://google.com/search?q=javascript', @prerender.build_api_url(request)
    end


    # Check X-Forwarded-Proto because Heroku SSL Support terminates at the load balancer
    it "should build the correct api url for the Heroku SSL Addon support with double value" do
      request = Rack::MockRequest.env_for "http://google.com/search?q=javascript", { 'X-FORWARDED-PROTO' => 'https,http'}
      ENV['PRERENDER_SERVICE_URL'] = nil
      assert_equal 'http://service.prerender.cloud/https://google.com/search?q=javascript', @prerender.build_api_url(request)
    end

    it "should build the correct api url for the protocol option" do
      @prerender = Rack::Prerendercloud.new(@app, protocol: 'https')
      request = Rack::MockRequest.env_for "http://google.com/search?q=javascript"
      ENV['PRERENDER_SERVICE_URL'] = nil
      assert_equal 'http://service.prerender.cloud/https://google.com/search?q=javascript', @prerender.build_api_url(request)
    end
  end

end
