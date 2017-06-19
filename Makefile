build:
	gem build prerendercloud.gemspec

publish:
	gem push $(shell ls -r *.gem | head -1)
