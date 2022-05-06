# prerendercloud-ruby

<img align="right" src="https://cloud.githubusercontent.com/assets/22159102/21554484/9d542f5a-cdc4-11e6-8c4c-7730a9e9e2d1.png">

Rack middleware for pre-rendering JavaScript single page apps with [Headless-Render-API.com](https://headless-render-api.com) (formerly named prerender.cloud from 2016 - 2022)


## Rails Usage

`Gemfile`

```ruby
gem 'prerendercloud'
```

`config/environment/production.rb`

```ruby

config.middleware.use Rack::Prerendercloud
# either hard code your secret token:
# config.middleware.use Rack::Prerendercloud, prerender_token: 'YOUR_TOKEN'
# or set the PRERENDER_TOKEN environment variable


```

### Bots only

We don't recommend this setting due to:

1. potential cloaking penalties
2. missing out on performance gains of prerendering all traffic

but it's here if you want it:

```ruby
config.middleware.use Rack::Prerendercloud, bots_only: true
```

### Blacklist

Prevent certain paths from being prerendered (e.g. JSON API endpoints)

Pass an array of Regexps or Strings.

```ruby
config.middleware.use Rack::Prerender, blacklist: [/^\/api/, '/housing_prices.json']
```

### Whitelist

Only allow certain paths to be prerendered

Pass an array of Regexps or Strings.

```ruby
config.middleware.use Rack::Prerender, whitelist: [/^\/users/, '/ips-v4']
```
