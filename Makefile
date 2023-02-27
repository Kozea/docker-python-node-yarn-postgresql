IMAGE_NAME ?= kozea/python-node-yarn-postgresql:bullseye

build: Dockerfile
	docker build -t $(IMAGE_NAME) .

publish: build
	docker push $(IMAGE_NAME)
