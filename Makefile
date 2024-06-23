ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

## For Docker <=20.04
export DOCKER_BUILDKIT=1
## For Docker <=20.04
export DOCKER_CLI_EXPERIMENTAL=enabled
## Required to have docker build output always printed on stdout
export BUILDKIT_PROGRESS=plain

current_arch := $(shell uname -m)
export ARCH ?= $(shell case $(current_arch) in (x86_64) echo "amd64" ;; (i386) echo "386";; (aarch64|arm64) echo "arm64" ;; (armv6*) echo "arm/v6";; (armv7*) echo "arm/v7";; (s390*|riscv*|ppc64le) echo $(current_arch);; (*) echo "UNKNOWN-CPU";; esac)

##### Macros
## Check the presence of a CLI in the current PATH
check_cli = type "$(1)" >/dev/null 2>&1 || { echo "Error: command '$(1)' required but not found. Exiting." ; exit 1 ; }
## Check if a given image exists in the current manifest docker-bake.hcl
check_image = make --silent list | grep -w '$(1)' >/dev/null 2>&1 || { echo "Error: the image '$(1)' does not exist in manifest for the platform 'linux/$(ARCH)'. Please check the output of 'make list'. Exiting." ; exit 1 ; }
## Base "docker buildx base" command to be reused everywhere
bake_base_cli := docker buildx bake -f docker-bake.hcl --load
bake_base_cli := docker buildx bake --file docker-bake.hcl
bake_cli := $(bake_base_cli) --load

.PHONY: build
.PHONY: test test-alpine test-archlinux test-debian test-jdk11 test-jdk11-alpine

check-reqs:
## Build requirements
	@$(call check_cli,bash)
	@$(call check_cli,git)
	@$(call check_cli,docker)
	@docker info | grep 'buildx:' >/dev/null 2>&1 || { echo "Error: Docker BuildX plugin required but not found. Exiting." ; exit 1 ; }
## Test requirements
	@$(call check_cli,curl)
	@$(call check_cli,jq)

## This function is specific to Jenkins infrastructure and isn't required in other contexts
docker-init: check-reqs
	@set -x; docker buildx create --use
	docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

build: check-reqs
	@set -x; $(bake_cli) --set '*.platform=linux/$(ARCH)' $(shell make --silent list)

build-%:
	@$(call check_image,$*)
	@echo "== building $*"
	@set -x; $(bake_cli) --set '*.platform=linux/$(ARCH)' '$*'

every-build: check-reqs
	@set -x; $(bake_base_cli) linux

show:
	@$(bake_cli) linux --print

list: check-reqs
	@set -x; make --silent show | jq -r '.target | path(.. | select(.platforms[] | contains("linux/$(ARCH)"))?) | add'

bats:
	git clone --branch v1.11.0 https://github.com/bats-core/bats-core ./bats

prepare-test: bats check-reqs
	git submodule update --init --recursive
	mkdir -p target

## Define bats options based on environment
# common flags for all tests
bats_flags := ""
# if DISABLE_PARALLEL_TESTS true, then disable parallel execution
ifneq (true,$(DISABLE_PARALLEL_TESTS))
# If the GNU 'parallel' command line is absent, then disable parallel execution
parallel_cli := $(shell command -v parallel 2>/dev/null)
ifneq (,$(parallel_cli))
# If parallel execution is enabled, then set 2 tests per core available for the Docker Engine
test-%: PARALLEL_JOBS ?= $(shell echo $$(( $(shell docker run --rm alpine grep -c processor /proc/cpuinfo) * 2)))
test-%: bats_flags += --jobs $(PARALLEL_JOBS)
endif
endif
test-%: prepare-test
# Check that the image exists in the manifest
	@$(call check_image,$*)
# Ensure that the image is built
	@make --silent build-$*
	@echo "== testing $*"
	set -x
# Each type of image ("agent" or "inbound-agent") has its own tests suite
	IMAGE=$* bats/bin/bats $(CURDIR)/tests/tests_$(shell echo $* |  cut -d "_" -f 1).bats $(bats_flags) --formatter junit | tee target/junit-results-$*.xml

test: prepare-test
	@make --silent list | while read image; do make --silent "test-$${image}"; done
