IMAGE ?= kozea/python-node-yarn-postgresql
TAG ?= cypress
# BUILD_ARGS :=, additional `docker build` arguments

CHROME_VERSION ?= 86.0.4240.193
FIREFOX_VERSION ?= 82.0.3

build: Dockerfile
	docker build \
		--tag $(IMAGE):$(TAG) \
		--build-arg CHROME_VERSION=$(CHROME_VERSION) \
		--build-arg FIREFOX_VERSION=$(FIREFOX_VERSION) \
		$(BUILD_ARGS) \
		.
