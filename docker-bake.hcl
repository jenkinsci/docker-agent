group "linux" {
  targets = [
    "alpine_jdk8",
    "alpine_jdk11",
    "alpine_jdk17",
    "archlinux_jdk11",
    "debian_jdk8",
    "debian_jdk11",
    "debian_jdk17",
  ]
}

group "linux-arm64" {
  targets = [
    "debian_jdk11",
    "debian_jdk17",
  ]
}

group "linux-arm32" {
  targets = [
    "debian_jdk11",
    "debian_jdk17",
  ]
}

group "linux-s390x" {
  targets = [
    "debian_jdk11",
  ]
}

group "linux-ppc64le" {
  targets = []
}

group "windows" {
  targets = [
    "windows_2019_jdk11",
  ]
}

variable "REMOTING_VERSION" {
  default = "4.3"
}

variable "REGISTRY" {
  default = "docker.io"
}

variable "JENKINS_REPO" {
  default = "jenkins/agent"
}

variable "BUILD_NUMBER" {
  default = "6"
}

variable "ON_TAG" {
  default = "false"
}

variable "ALPINE_FULL_TAG" {
  default = "3.16.2"
}

variable "ALPINE_SHORT_TAG" {
  default = regex_replace(ALPINE_FULL_TAG, "\\.\\d+$", "")
}

target "archlinux_jdk11" {
  dockerfile = "11/archlinux/Dockerfile"
  context = "."
  args = {
    VERSION = REMOTING_VERSION
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-archlinux": "",
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-archlinux-jdk11" : "",
    "${REGISTRY}/${JENKINS_REPO}:archlinux",
    "${REGISTRY}/${JENKINS_REPO}:latest-archlinux",
    "${REGISTRY}/${JENKINS_REPO}:archlinux-jdk11",
    "${REGISTRY}/${JENKINS_REPO}:latest-archlinux-jdk11",
  ]
  platforms = ["linux/amd64"]
}

target "alpine_jdk8" {
  dockerfile = "8/alpine/Dockerfile"
  context = "."
  args = {
    ALPINE_TAG = ALPINE_FULL_TAG
    VERSION = REMOTING_VERSION
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-alpine-jdk8": "",
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-alpine${ALPINE_SHORT_TAG}-jdk8": "",
    "${REGISTRY}/${JENKINS_REPO}:alpine-jdk8",
    "${REGISTRY}/${JENKINS_REPO}:alpine${ALPINE_SHORT_TAG}-jdk8",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine-jdk8",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine${ALPINE_SHORT_TAG}-jdk8",
  ]
  platforms = ["linux/amd64"]
}

target "alpine_jdk11" {
  dockerfile = "11/alpine/Dockerfile"
  context = "."
  args = {
    ALPINE_TAG = ALPINE_FULL_TAG
    VERSION = REMOTING_VERSION
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-alpine": "",
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-alpine${ALPINE_SHORT_TAG}": "",
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-alpine-jdk11": "",
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-alpine${ALPINE_SHORT_TAG}-jdk11": "",
    "${REGISTRY}/${JENKINS_REPO}:alpine",
    "${REGISTRY}/${JENKINS_REPO}:alpine${ALPINE_SHORT_TAG}",
    "${REGISTRY}/${JENKINS_REPO}:alpine-jdk11",
    "${REGISTRY}/${JENKINS_REPO}:alpine${ALPINE_SHORT_TAG}-jdk11",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine${ALPINE_SHORT_TAG}",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine-jdk11",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine${ALPINE_SHORT_TAG}-jdk11",
  ]
  platforms = ["linux/amd64"]
}

target "alpine_jdk17" {
  dockerfile = "17/alpine/Dockerfile"
  context = "."
  args = {
    ALPINE_TAG = ALPINE_FULL_TAG
    VERSION = REMOTING_VERSION
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-alpine-jdk17": "",
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-alpine${ALPINE_SHORT_TAG}-jdk17": "",
    "${REGISTRY}/${JENKINS_REPO}:alpine-jdk17-preview",
    "${REGISTRY}/${JENKINS_REPO}:alpine${ALPINE_SHORT_TAG}-jdk17-preview",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine-jdk17-preview",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine${ALPINE_SHORT_TAG}-jdk17-preview",
  ]
  platforms = ["linux/amd64"]
}

target "debian_jdk8" {
  dockerfile = "8/bullseye/Dockerfile"
  context = "."
  args = {
    VERSION = REMOTING_VERSION
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-jdk8": "",
    "${REGISTRY}/${JENKINS_REPO}:bullseye-jdk8",
    "${REGISTRY}/${JENKINS_REPO}:jdk8",
    "${REGISTRY}/${JENKINS_REPO}:latest-bullseye-jdk8",
    "${REGISTRY}/${JENKINS_REPO}:latest-jdk8",
  ]
  platforms = ["linux/amd64"]
}

target "debian_jdk11" {
  dockerfile = "11/bullseye/Dockerfile"
  context = "."
  args = {
    VERSION = REMOTING_VERSION
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}": "",
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-jdk11": "",
    "${REGISTRY}/${JENKINS_REPO}:bullseye-jdk11",
    "${REGISTRY}/${JENKINS_REPO}:jdk11",
    "${REGISTRY}/${JENKINS_REPO}:latest",
    "${REGISTRY}/${JENKINS_REPO}:latest-bullseye-jdk11",
    "${REGISTRY}/${JENKINS_REPO}:latest-jdk11",
  ]
  platforms = ["linux/amd64", "linux/arm64", "linux/arm/v7", "linux/s390x"]
}

target "debian_jdk17" {
  dockerfile = "17/bullseye/Dockerfile"
  context = "."
  args = {
    VERSION = REMOTING_VERSION
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-jdk17-preview": "",
    "${REGISTRY}/${JENKINS_REPO}:bullseye-jdk17-preview",
    "${REGISTRY}/${JENKINS_REPO}:jdk17-preview",
    "${REGISTRY}/${JENKINS_REPO}:latest-bullseye-jdk17-preview",
    "${REGISTRY}/${JENKINS_REPO}:latest-jdk17-preview",
  ]
  platforms = ["linux/amd64", "linux/arm64", "linux/arm/v7"]
}
