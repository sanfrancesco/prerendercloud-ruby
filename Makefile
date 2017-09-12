build:
	gem build prerendercloud.gemspec

publish: build
	gem push $(shell ls -r *.gem | head -1)
