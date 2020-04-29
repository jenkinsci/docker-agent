ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

IMAGE_NAME:=jenkins4eval/agent
IMAGE_NAME_AGENT:=jenkins4eval/slave

.PHONY: build
.PHONY: test test-alpine test-debian test-debian-buster test-jdk11 test-jdk11-buster

build: build-alpine build-debian build-debian-buster build-jdk11 build-jdk11-buster

build-alpine:
	docker build -t ${IMAGE_NAME}:alpine \
                 -t ${IMAGE_NAME}:jdk8-alpine \
                 -t ${IMAGE_NAME}:jdk8-alpine3.9 \
                 -t ${IMAGE_NAME_AGENT}:alpine \
                 8/alpine/

build-debian:
	docker build -t ${IMAGE_NAME}:latest \
                 -t ${IMAGE_NAME}:stretch \
                 -t ${IMAGE_NAME}:jdk8-stretch \
                 8/debian/stretch/

build-debian-buster:
	docker build -t ${IMAGE_NAME}:latest \
                 -t ${IMAGE_NAME}:jdk8 \
                 -t ${IMAGE_NAME}:jdk8-buster \
                 -t ${IMAGE_NAME_AGENT}:latest \
                 8/debian/buster/

build-jdk11:
	docker build -t ${IMAGE_NAME}:jdk11 \
                 -t ${IMAGE_NAME}:jdk11-stretch \
                 11/debian/stretch/

build-jdk11-buster:
	docker build -t ${IMAGE_NAME}:jdk11-buster \
                -t ${IMAGE_NAME_AGENT}:jdk11-buster \
                -t ${IMAGE_NAME_AGENT}:jdk11 \
                11/debian/buster/

bats:
# The lastest version is v1.1.0
	@if [ ! -d bats-core ]; then git clone https://github.com/bats-core/bats-core.git; fi
	@git -C bats-core reset --hard c706d1470dd1376687776bbe985ac22d09780327

test: test-alpine test-debian test-debian-buster test-jdk11 test-jdk11-buster

test-alpine: bats
	@FOLDER="8/alpine" bats-core/bin/bats tests/tests.bats

test-debian: bats
	@FOLDER="8/debian/stretch"   bats-core/bin/bats tests/tests.bats

test-debian-buster: bats
	@FOLDER="8/debian/buster"   bats-core/bin/bats tests/tests.bats

test-jdk11: bats
	@FOLDER="11/debian/stretch"  bats-core/bin/bats tests/tests.bats

test-jdk11-buster: bats
	@FOLDER="11/debian/buster"   bats-core/bin/bats tests/tests.bats
