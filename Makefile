.PHONY: clean build run dev all
.DEFAULT_GOAL := all

IMAGE?=jnovack/mailserver
TAG?=latest

all: build

clean:
	docker rmi $(IMAGE):$(TAG) || true

build:
	docker build \
		--build-arg BUILD_RFC3339=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
		--build-arg COMMIT=$(git rev-parse --short HEAD) \
		--build-arg VERSION=$(git describe --tags --always) \
		-t $(IMAGE):$(TAG) .

dev:
	docker build \
		--build-arg BUILD_RFC3339=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
		--build-arg COMMIT=$(git rev-parse --short HEAD) \
		--build-arg VERSION=$(git describe --tags --always) \
		-t $(IMAGE):dev .