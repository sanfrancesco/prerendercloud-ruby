![image](https://cloud.githubusercontent.com/assets/22159102/21554484/9d542f5a-cdc4-11e6-8c4c-7730a9e9e2d1.png)

# prerendercloud-ruby

Rack middleware for server-side rendering (prerendering) JavaScript web pages/apps (single page apps or SPA) with [https://www.prerender.cloud/](https://www.prerender.cloud/)


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
