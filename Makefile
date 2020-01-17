ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
IMAGE_NAME:=jenkins4eval/slave
IMAGE_NAME_AGENT:=jenkins4eval/agent

build:
	docker build -t ${IMAGE_NAME}:latest -t ${IMAGE_NAME_AGENT}:latest .
	docker build -t ${IMAGE_NAME}:alpine -t ${IMAGE_NAME_AGENT}:alpine -f Dockerfile-alpine .
	docker build -t ${IMAGE_NAME}:jdk11  -t ${IMAGE_NAME_AGENT}:jdk11  -f Dockerfile-jdk11  .

.PHONY: tests
tests:
	@bats tests/tests.bats
	@FLAVOR=alpine bats tests/tests.bats
	@FLAVOR=jdk11 bats tests/tests.bats
