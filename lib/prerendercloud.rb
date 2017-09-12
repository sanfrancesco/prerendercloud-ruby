module Rack
  class Prerendercloud
    require 'net/http'
    require 'active_support'

    class << self

      def header_whitelist
         # preserve (and send to client) these headers from service.prerender.cloud
         # which originally came from the origin server
        return [
          "vary",
          "content-type",
          "cache-control",
          "strict-transport-security",
          "content-security-policy",
          "public-key-pins",
          "x-frame-options",
          "x-xss-protection",
          "x-content-type-options",
          "location"
        ];
      end

      def normalize_headers(headers)
        filtered = headers.select { |key, value| header_whitelist.any? { |h| key.to_s.match(/#{h}/i) } }

        mapped = filtered.map do |k, v|
          [k, if v.is_a? Array then v.join("\n") else v end]
        end
        Utils::HeaderHash.new Hash[mapped]
      end
    end

    def initialize(app, options={})
      # googlebot, yahoo, and bingbot are not in this list because
      # we support _escaped_fragment_ and want to ensure people aren't
      # penalized for cloaking.
      @crawler_user_agents = [
        'googlebot',
        'yahoo',
        'bingbot',
        'baiduspider',
        'facebookexternalhit',
        'twitterbot',
        'rogerbot',
        'linkedinbot',
        'embedly',
        'bufferbot',
        'quora link preview',
        'showyoubot',
        'outbrain',
        'pinterest/0.',
        'developers.google.com/+/web/snippet',
        'www.google.com/webmasters/tools/richsnippets',
        'slackbot',
        'vkShare',
        'W3C_Validator',
        'redditbot',
        'Applebot',
        'WhatsApp',
        'flipboard',
        'tumblr',
        'bitlybot',
        'SkypeUriPreview',
        'nuzzel',
        'Discordbot',
        'Google Page Speed',
        'Qwantify'
      ]

      @options = options
      @options[:whitelist] = [@options[:whitelist]] if @options[:whitelist].is_a? String
      @options[:blacklist] = [@options[:blacklist]] if @options[:blacklist].is_a? String
      @crawler_user_agents = @options[:crawler_user_agents] if @options[:crawler_user_agents]
      @app = app
    end


    def call(env)
      if should_show_prerendered_page(env)

        cached_response = before_render(env)

        if cached_response
          return cached_response.finish
        end

        prerendered_response = get_prerendered_page_response(env)

        if prerendered_response
          response = build_rack_response_from_prerender(prerendered_response)
          after_render(env, prerendered_response)
          return response.finish
        end
      end

      @app.call(env)
    end


    def should_show_prerendered_page(env)
      user_agent = env['HTTP_USER_AGENT']
      buffer_agent = env['HTTP_X_BUFFERBOT']
      is_requesting_prerendered_page = false

      return false if !user_agent
      return false if env['REQUEST_METHOD'] != 'GET'
      return false if user_agent.match(/prerendercloud/i);

      request = Rack::Request.new(env)

      return false if !prerenderable_extension(request.fullpath);

      #if it is a bot...show prerendered page
      if (@options[:bots_only])
        is_requesting_prerendered_page = true if @crawler_user_agents.any? { |crawler_user_agent| user_agent.downcase.include?(crawler_user_agent.downcase) }

        #if it is BufferBot...show prerendered page
        is_requesting_prerendered_page = true if buffer_agent
      else
        is_requesting_prerendered_page = true
      end

      is_requesting_prerendered_page = true if Rack::Utils.parse_query(request.query_string).has_key?('_escaped_fragment_')

      # if whitelist exists and path is not whitelisted...don't prerender
      return false if @options[:whitelist].is_a?(Array) && @options[:whitelist].all? do |whitelisted|
        if whitelisted.is_a?(Regexp)
          !whitelisted.match(request.fullpath)
        else
          whitelisted != request.fullpath;
        end
      end

      # if blacklist exists and path is blacklisted(url or referer)...don't prerender
      if @options[:blacklist].is_a?(Array) && @options[:blacklist].any? do |blacklisted|
          blacklistedUrl = false
          blacklistedReferer = false

          if blacklisted.is_a?(Regexp)
            blacklistedUrl = !!blacklisted.match(request.fullpath)
            blacklistedReferer = !!blacklisted.match(request.referer) if request.referer
          else
            blacklistedUrl = blacklisted == request.fullpath
            blacklistedReferer = request.referer && blacklisted == request.referer
          end

          blacklistedUrl || blacklistedReferer
        end
        return false
      end

      return is_requesting_prerendered_page
    end

    def prerenderable_extension(fullpath)

      path = URI.parse(fullpath).path;

      # doesn't detect index.whatever.html (multiple dots)
      hasHtmlOrNoExtension = !!path.match(/^(([^.]|\.html?)+)$/);

      return true if hasHtmlOrNoExtension

      # hack to handle basenames with multiple dots: index.whatever.html
      endsInHtml = !!path.match(/.html?$/);

      return true if endsInHtml

      return false;

    end

    def get_prerendered_page_response(env)
      begin
        url = URI.parse(build_api_url(env))
        headers = {
          'User-Agent' => env['HTTP_USER_AGENT'],
          'Accept-Encoding' => 'gzip'
        }
        headers['X-Prerender-Token'] = ENV['PRERENDER_TOKEN'] if ENV['PRERENDER_TOKEN']
        headers['X-Prerender-Token'] = @options[:prerender_token] if @options[:prerender_token]
        req = Net::HTTP::Get.new(url.request_uri, headers)
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true if url.scheme == 'https'
        response = http.request(req)
        if response['Content-Encoding'] == 'gzip'
          response.body = ActiveSupport::Gzip.decompress(response.body)
          response['Content-Length'] = response.body.length
          response.delete('Content-Encoding')
        end
        response
      rescue => e
        puts "Error: #{e.class.name}"
        nil
      end
    end


    def build_api_url(env)
      new_env = env
      if env["CF-VISITOR"]
        match = /"scheme":"(http|https)"/.match(env['CF-VISITOR'])
        new_env["HTTPS"] = true and new_env["rack.url_scheme"] = "https" and new_env["SERVER_PORT"] = 443 if (match && match[1] == "https")
        new_env["HTTPS"] = false and new_env["rack.url_scheme"] = "http" and new_env["SERVER_PORT"] = 80 if (match && match[1] == "http")
      end

      if env["X-FORWARDED-PROTO"]
        new_env["HTTPS"] = true and new_env["rack.url_scheme"] = "https" and new_env["SERVER_PORT"] = 443 if env["X-FORWARDED-PROTO"].split(',')[0] == "https"
        new_env["HTTPS"] = false and new_env["rack.url_scheme"] = "http" and new_env["SERVER_PORT"] = 80 if env["X-FORWARDED-PROTO"].split(',')[0] == "http"
      end

      if @options[:protocol]
        new_env["HTTPS"] = true and new_env["rack.url_scheme"] = "https" and new_env["SERVER_PORT"] = 443 if @options[:protocol] == "https"
        new_env["HTTPS"] = false and new_env["rack.url_scheme"] = "http" and new_env["SERVER_PORT"] = 80 if @options[:protocol] == "http"
      end

      url = Rack::Request.new(new_env).url
      puts "Requesting prerendered page for #{url}"
      prerender_url = get_prerender_service_url()
      forward_slash = prerender_url[-1, 1] == '/' ? '' : '/'
      "#{prerender_url}#{forward_slash}#{url}"
    end


    def get_prerender_service_url
      @options[:prerender_service_url] || ENV['PRERENDER_SERVICE_URL'] || 'http://service.prerender.cloud/'
    end


    def build_rack_response_from_prerender(prerendered_response)

      headers = (prerendered_response.respond_to?(:headers) && prerendered_response.headers) || self.class.normalize_headers(prerendered_response.to_hash)

      response = Rack::Response.new(prerendered_response.body, prerendered_response.code, headers)


      @options[:build_rack_response_from_prerender].call(response, prerendered_response) if @options[:build_rack_response_from_prerender]

      response
    end

    def before_render(env)
      return nil unless @options[:before_render]

      cached_render = @options[:before_render].call(env)

      if cached_render && cached_render.is_a?(String)
        Rack::Response.new(cached_render, 200, { 'Content-Type' => 'text/html; charset=utf-8' })
      elsif cached_render && cached_render.is_a?(Rack::Response)
        cached_render
      else
        nil
      end
    end


    def after_render(env, response)
      return true unless @options[:after_render]
      @options[:after_render].call(env, response)
    end
  end
end
