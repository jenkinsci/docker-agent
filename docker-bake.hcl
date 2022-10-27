group "linux" {
  targets = [
    "alpine_jdk8",
    "debian_jdk8",
  ]
}

group "linux-arm64" {
  targets = [
  ]
}

group "linux-arm32" {
  targets = [
  ]
}

group "linux-s390x" {
  targets = [
  ]
}

group "windows" {
  targets = [
  ]
}

variable "REMOTING_VERSION" {
  default = "3028.va_a_436db_35078"
}

variable "REGISTRY" {
  default = "docker.io"
}

variable "JENKINS_REPO" {
  default = "jenkins/agent"
}

variable "BUILD_NUMBER" {
  default = "3"
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
