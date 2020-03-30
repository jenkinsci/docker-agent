ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

IMAGE_NAME:=jenkins4eval/agent
IMAGE_NAME_AGENT:=jenkins4eval/slave

.PHONY: build
.PHONY: test test-alpine test-debian test-jdk11 test-jdk11-buster

build: build-alpine build-debian build-jdk11 build-jdk11-buster

build-alpine:
	docker build -t ${IMAGE_NAME}:alpine \
                 -t ${IMAGE_NAME}:jdk8-alpine \
                 -t ${IMAGE_NAME}:jdk8-alpine3.9 \
                 -t ${IMAGE_NAME_AGENT}:alpine \
                 8/alpine3.9/

build-debian:
	docker build -t ${IMAGE_NAME}:latest \
                 -t ${IMAGE_NAME}:jdk8 \
                 -t ${IMAGE_NAME}:stretch \
                 -t ${IMAGE_NAME}:jdk8-stretch \
                 -t ${IMAGE_NAME_AGENT}:latest \
                 8/stretch/

build-jdk11:
	docker build -t ${IMAGE_NAME}:jdk11 \
                 -t ${IMAGE_NAME}:jdk11-stretch \
                 -t ${IMAGE_NAME_AGENT}:jdk11 \
                 11/stretch/

build-jdk11-buster:
	docker build -t ${IMAGE_NAME}:jdk11-buster \
				 -t ${IMAGE_NAME_AGENT}:jdk11-buster \
				 11/buster/

bats:
# The lastest version is v1.1.0
	@if [ ! -d bats-core ]; then git clone https://github.com/bats-core/bats-core.git; fi
	@git -C bats-core reset --hard c706d1470dd1376687776bbe985ac22d09780327

test: test-alpine test-debian test-jdk11 test-jdk11-buster

test-alpine: bats
	@FOLDER="8/alpine3.9" bats-core/bin/bats tests/tests.bats

test-debian: bats
	@FOLDER="8/stretch"   bats-core/bin/bats tests/tests.bats

test-jdk11: bats
	@FOLDER="11/stretch"  bats-core/bin/bats tests/tests.bats

test-jdk11-buster: bats
	@FOLDER="11/buster"   bats-core/bin/bats tests/tests.bats
