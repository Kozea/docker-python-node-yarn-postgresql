build: Dockerfile
	docker build -t kozea/docker-python-node-yarn-postgresql:bullseye-test .

build-test: Dockerfile.copy
	docker build -t kozea/docker-python-node-yarn-postgresql:bullseye-test2 - < $<