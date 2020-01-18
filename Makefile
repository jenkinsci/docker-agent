ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
IMAGE_NAME:=jenkins4eval/slave
IMAGE_NAME_AGENT:=jenkins4eval/agent

build:
	docker build -t ${IMAGE_NAME}:latest -t ${IMAGE_NAME_AGENT}:latest .
	docker build -t ${IMAGE_NAME}:alpine -t ${IMAGE_NAME_AGENT}:alpine -f Dockerfile-alpine .
	docker build -t ${IMAGE_NAME}:jdk11  -t ${IMAGE_NAME_AGENT}:jdk11  -f Dockerfile-jdk11  .

.PHONY: tests
tests: bats
	@FLAVOR=       bats-core/bin/bats tests/tests.bats
	@FLAVOR=alpine bats-core/bin/bats tests/tests.bats
	@FLAVOR=jdk11  bats-core/bin/bats tests/tests.bats

bats:
# The lastest version is v1.1.0
	@if [ ! -d bats-core ]; then git clone git@github.com:bats-core/bats-core.git; fi
	@cd bats-core && git reset --hard c706d1470dd1376687776bbe985ac22d09780327 &> /dev/null