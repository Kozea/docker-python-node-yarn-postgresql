build: Dockerfile
	docker build -t kozea/python-node-yarn-postgresql:bullseye .

publish: build
	docker push kozea/python-node-yarn-postgresql:bullseye
