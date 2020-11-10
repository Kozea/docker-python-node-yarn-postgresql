IMAGE ?= kozea/python-node-yarn-postgresql
TAG ?= latest
# BUILD_ARGS :=, additional `docker build` arguments

build: Dockerfile
	docker build \
		--tag $(IMAGE):$(TAG) \
		$(BUILD_ARGS) \
		.
