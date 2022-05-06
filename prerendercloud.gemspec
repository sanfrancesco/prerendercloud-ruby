# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = "prerendercloud"
  spec.version       = "0.2.0"
  spec.authors       = ["Jonathan Otto"]
  spec.email         = ["support@headless-render-api.com"]
  spec.description   = %q{Rack middleware to server-side render your JavaScript apps by headless-render-api.com}
  spec.summary       = %q{Rack middleware to server-side render your JavaScript apps by headless-render-api.com}
  spec.homepage      = "https://github.com/sanfrancesco/prerendercloud-ruby"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'rack', '>= 0'
  spec.add_dependency 'activesupport', '>= 0'

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "webmock"
end
