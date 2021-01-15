ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

IMAGE_NAME:=jenkins4eval/agent
IMAGE_NAME_AGENT:=jenkins4eval/slave

.PHONY: build
.PHONY: test test-alpine test-debian test-debian-buster test-jdk11 test-jdk11-alpine test-jdk11-buster

build: build-alpine build-debian build-debian-buster build-jdk11 build-jdk11-alpine build-jdk11-buster

build-alpine:
	docker build -t ${IMAGE_NAME}:alpine \
                 -t ${IMAGE_NAME}:jdk8-alpine \
                 -t ${IMAGE_NAME}:jdk8-alpine3.9 \
                 -t ${IMAGE_NAME_AGENT}:alpine \
                 8/alpine/

build-debian:
	docker build -t ${IMAGE_NAME}:stretch \
                 -t ${IMAGE_NAME}:jdk8-stretch \
                 8/stretch/

build-debian-buster:
	docker build -t ${IMAGE_NAME}:latest \
                 -t ${IMAGE_NAME}:jdk8 \
                 -t ${IMAGE_NAME}:jdk8-buster \
                 -t ${IMAGE_NAME_AGENT}:latest \
                 8/buster/

build-jdk11:
	docker build -t ${IMAGE_NAME}:jdk11 \
                 -t ${IMAGE_NAME}:jdk11-stretch \
                 11/stretch/

build-jdk11-alpine:
	docker build -t ${IMAGE_NAME}:alpine \
                 -t ${IMAGE_NAME}:jdk11-alpine \
                 -t ${IMAGE_NAME}:jdk11-alpine3.9 \
                 -t ${IMAGE_NAME_AGENT}:alpine \
                 11/alpine/

build-jdk11-buster:
	docker build -t ${IMAGE_NAME}:jdk11-buster \
                 -t ${IMAGE_NAME_AGENT}:jdk11-buster \
                 -t ${IMAGE_NAME_AGENT}:jdk11 \
                 11/buster/

bats:
# The lastest version is v1.1.0
	@if [ ! -d bats-core ]; then git clone https://github.com/bats-core/bats-core.git; fi
	@git -C bats-core reset --hard c706d1470dd1376687776bbe985ac22d09780327

prepare-test: bats
	mkdir -p target

test-run-%: build prepare-test
	FOLDER="${FOLDER}" bats-core/bin/bats tests/tests.bats | tee target/results-$*.tap
	docker run --rm -v "${PWD}":/usr/src/app \
					-w /usr/src/app node:12-alpine \
					sh -c "npm install tap-xunit -g && cat target/results-$*.tap | tap-xunit --package='jenkinsci.docker-agent.$*' > target/junit-results-$*.xml"

test: test-alpine test-debian test-debian-buster test-jdk11 test-jdk11-buster

test-alpine: FOLDER=8/alpine
test-alpine: test-run-alpine

test-debian: FOLDER=8/stretch
test-debian: test-run-debian

test-debian-buster: FOLDER=8/buster
test-debian-buster: test-run-debian-buster

test-jdk11: FOLDER=11/stretch
test-jdk11: test-run-debian-jdk11

test-jdk11-alpine: FOLDER=11/alpine
test-jdk11-alpine: test-run-debian-jdk11-alpine

test-jdk11-buster: FOLDER=11/buster
test-jdk11-buster: test-run-debian-jdk11-buster
