group "linux" {
  targets = [
    "alpine_jdk11",
    "alpine_jdk17",
    "archlinux_jdk11",
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
    "debian_jdk17"
  ]
}

group "linux-s390x" {
  targets = [
    "debian_jdk11",
  ]
}

group "linux-ppc64le" {
  targets = [
    "debian_jdk11",
    "debian_jdk17",
  ]
}

group "windows" {
  targets = [
    "windows_2019_jdk11",
  ]
}

variable "REMOTING_VERSION" {
  default = "3131.vf2b_b_798b_ce99"
}

variable "REGISTRY" {
  default = "docker.io"
}

variable "JENKINS_REPO" {
  default = "jenkins/agent"
}

variable "BUILD_NUMBER" {
  default = "1"
}

variable "ON_TAG" {
  default = "false"
}

variable "ALPINE_FULL_TAG" {
  default = "3.18.2"
}

variable "ALPINE_SHORT_TAG" {
  default = regex_replace(ALPINE_FULL_TAG, "\\.\\d+$", "")
}

variable "JAVA11_VERSION" {
  default = "11.0.19_7"
}

variable "JAVA17_VERSION" {
  default = "17.0.7_7"
}

target "archlinux_jdk11" {
  dockerfile = "archlinux/Dockerfile"
  context = "."
  args = {
    JAVA_VERSION = JAVA11_VERSION
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

target "alpine_jdk11" {
  dockerfile = "alpine/Dockerfile"
  context = "."
  args = {
    ALPINE_TAG = ALPINE_FULL_TAG
    JAVA_VERSION = JAVA11_VERSION
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
  dockerfile = "alpine/Dockerfile"
  context = "."
  args = {
    ALPINE_TAG = ALPINE_FULL_TAG
    JAVA_VERSION = JAVA17_VERSION
    VERSION = REMOTING_VERSION
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-alpine-jdk17": "",
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-alpine${ALPINE_SHORT_TAG}-jdk17": "",
    "${REGISTRY}/${JENKINS_REPO}:alpine-jdk17",
    "${REGISTRY}/${JENKINS_REPO}:alpine${ALPINE_SHORT_TAG}-jdk17",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine-jdk17",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine${ALPINE_SHORT_TAG}-jdk17",
  ]
  platforms = ["linux/amd64"]
}

target "debian_jdk11" {
  dockerfile = "debian/Dockerfile"
  context = "."
  args = {
    JAVA_VERSION = JAVA11_VERSION
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
  platforms = ["linux/amd64", "linux/arm64", "linux/arm/v7", "linux/s390x", "linux/ppc64le"]
}

target "debian_jdk17" {
  dockerfile = "debian/Dockerfile"
  context = "."
  args = {
    JAVA_VERSION = JAVA17_VERSION
    VERSION = REMOTING_VERSION,
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-jdk17": "",
    "${REGISTRY}/${JENKINS_REPO}:bullseye-jdk17",
    "${REGISTRY}/${JENKINS_REPO}:jdk17",
    "${REGISTRY}/${JENKINS_REPO}:latest-bullseye-jdk17",
    "${REGISTRY}/${JENKINS_REPO}:latest-jdk17",
  ]
  platforms = ["linux/amd64", "linux/arm64", "linux/arm/v7", "linux/ppc64le"]
}
