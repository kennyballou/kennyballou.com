TAG=kennyballou
all: build
.PHONY: all build container blog

build: container blog

container:
	@docker build -t ${TAG} .
