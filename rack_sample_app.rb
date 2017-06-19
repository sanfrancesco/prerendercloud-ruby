require 'rack'

require_relative './lib/prerendercloud'

class RackSampleApp
  def call(env)
    req = Rack::Request.new(env)
    case req.path_info
    when /main.js/
      [200, {"Content-Type" => "application/javascript"}, ["document.getElementById('root').innerHTML = 'js-app';"]]
    else
      [200, {"Content-Type" => "text/html"}, ["<html><body><div id='root'></div><script src='/main.js'></script></body></html>"]]
    end
  end
end


app = Rack::Builder.new do
  use Rack::Prerendercloud
  run RackSampleApp.new
end

Rack::Handler::WEBrick.run app
