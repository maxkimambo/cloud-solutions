# Project name (used for output binary name)
PROJECT_NAME := gcp-log-exporter

# Go related variables.
GOBASE := $(shell pwd)
GOPATH := $(GOBASE)/vendor:$(GOBASE)
GOBIN := $(GOBASE)/build
GOFILES := $(wildcard *.go)
DOCKER_IMAGE_NAME := europe-west3-docker.pkg.dev/kim-sap-sp-seed/log-exporter/gcp-log-exporter
TAG := $$(git log -1 --pretty=%h)

all: clean build docker-build 

build: ## Build the binary
	@echo "  >  Building binary..."
	@GOPATH=$(GOPATH) GOBIN=$(GOBIN) go build -o $(GOBIN)/$(PROJECT_NAME) $(GOFILES)

run: ## Run the application
	@echo "  >  Running binary..."
	@GOPATH=$(GOPATH) GOBIN=$(GOBIN) go run $(GOFILES)

clean: ## Clean the application
	@echo "  >  Cleaning build cache"
	@GOPATH=$(GOPATH) GOBIN=$(GOBIN) go clean
	@rm -rf $(GOBIN)

install: ## Install the dependencies
	@echo "  >  Installing dependencies..."
	@GOPATH=$(GOPATH) GOBIN=$(GOBIN) go mod download

# test: ## Run tests
# 	@echo "  >  Running tests..."
# 	@GOPATH=$(GOPATH) GOBIN=$(GOBIN) go test

docker-build:
	@echo "  >  Building docker image... ${TAG}"
	docker build -t ${DOCKER_IMAGE_NAME}:${TAG} .
	docker tag ${DOCKER_IMAGE_NAME}:${TAG} ${PROJECT_NAME}:latest
	docker tag ${DOCKER_IMAGE_NAME}:${TAG} ${DOCKER_IMAGE_NAME}:latest

docker-push:
	@echo "  >  Pushing docker image... ${TAG}"
	docker push ${DOCKER_IMAGE_NAME}:${TAG}
	docker push ${DOCKER_IMAGE_NAME}:latest