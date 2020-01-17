ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
IMAGE_NAME:=jenkins4eval/slave
IMAGE_NAME_AGENT:=jenkins4eval/agent

build:
	docker build -t ${IMAGE_NAME}:alpine -t ${IMAGE_NAME_AGENT}:alpine  8/alpine3.6/
	docker build -t ${IMAGE_NAME}:latest -t ${IMAGE_NAME_AGENT}:latest  8/stretch/
	docker build -t ${IMAGE_NAME}:jdk11  -t ${IMAGE_NAME_AGENT}:jdk11  11/stretch/

.PHONY: tests
tests:
	@FOLDER="8/alpine3.6" bats tests/tests.bats
	@FOLDER="8/stretch"   bats tests/tests.bats
	@FOLDER="11/stretch"  bats tests/tests.bats
