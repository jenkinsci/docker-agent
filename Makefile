ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

IMAGE_NAME:=jenkins4eval/slave
IMAGE_NAME_AGENT:=jenkins4eval/agent

.PHONY: build build-alpine build-debian build-jdk11
.PHONY: test test-alpine test-debian test-jdk11

build: build-alpine build-debian build-jdk11

build-alpine:
	docker build -t ${IMAGE_NAME}:alpine -t ${IMAGE_NAME_AGENT}:alpine 8/alpine3.6/

build-debian:
	docker build -t ${IMAGE_NAME}:latest -t ${IMAGE_NAME_AGENT}:latest 8/stretch/

build-jdk11:
	docker build -t ${IMAGE_NAME}:jdk11  -t ${IMAGE_NAME_AGENT}:jdk11 11/stretch/


bats:
# The lastest version is v1.1.0
	@if [ ! -d bats-core ]; then git clone https://github.com/bats-core/bats-core.git &>/dev/null; fi
	@git -C bats-core reset --hard c706d1470dd1376687776bbe985ac22d09780327 &>/dev/null


test: test-alpine test-debian test-jdk11

test-alpine: bats
	@FOLDER="8/alpine3.6" bats-core/bin/bats tests/tests.bats

test-debian: bats
	@FOLDER="8/stretch"   bats-core/bin/bats tests/tests.bats

test-jdk11: bats
	@FOLDER="11/stretch"  bats-core/bin/bats tests/tests.bats
