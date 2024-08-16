group "linux" {
  targets = [
    "agent_archlinux_jdk11",
    "alpine",
    "debian"
  ]
}

group "linux-agent-only" {
  targets = [
    "agent_archlinux_jdk11",
    "agent_alpine_jdk11",
    "agent_alpine_jdk17",
    "agent_alpine_jdk21",
    "agent_debian_jdk11",
    "agent_debian_jdk17",
    "agent_debian_jdk21"
  ]
}

group "linux-inbound-agent-only" {
  targets = [
    "inbound-agent_alpine_jdk11",
    "inbound-agent_alpine_jdk17",
    "inbound-agent_alpine_jdk21",
    "inbound-agent_debian_jdk11",
    "inbound-agent_debian_jdk17",
    "inbound-agent_debian_jdk21"
  ]
}

group "linux-arm64" {
  targets = [
    "debian",
    "alpine_jdk21",
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
    "debian_jdk21"
  ]
}

group "linux-ppc64le" {
  targets = [
    "debian"
  ]
}

variable "REMOTING_VERSION" {
  default = "3261.v9c670a_4748a_9"
}

variable "REGISTRY" {
  default = "docker.io"
}

variable "REGISTRY_ORG" {
  default = "jenkins"
}

variable "REGISTRY_REPO_AGENT" {
  default = "agent"
}

variable "REGISTRY_REPO_INBOUND_AGENT" {
  default = "inbound-agent"
}

variable "BUILD_NUMBER" {
  default = "1"
}

variable "ON_TAG" {
  default = "false"
}

variable "ALPINE_FULL_TAG" {
  default = "3.20.2"
}

variable "ALPINE_SHORT_TAG" {
  default = regex_replace(ALPINE_FULL_TAG, "\\.\\d+$", "")
}

variable "DEBIAN_RELEASE" {
  default = "bookworm-20240812"
}

variable "JAVA11_VERSION" {
  default = "11.0.24_8"
}

variable "JAVA17_VERSION" {
  default = "17.0.12_7"
}

variable "JAVA21_VERSION" {
  default = "21.0.4_7"
}

function "orgrepo" {
  params = [agentType]
  result = equal("agent", agentType) ? "${REGISTRY_ORG}/${REGISTRY_REPO_AGENT}" : "${REGISTRY_ORG}/${REGISTRY_REPO_INBOUND_AGENT}"
}

variable "default_jdk" {
  default = 17
}

# Return "true" if the jdk passed as parameter is the same as the default jdk, "false" otherwise
function "is_default_jdk" {
  params = [jdk]
  result = equal(default_jdk, jdk) ? true : false
}

# Return the complete Java version corresponding to the jdk passed as parameter
function "javaversion" {
  params = [jdk]
  result = (equal(11, jdk)
    ? "${JAVA11_VERSION}"
    : (equal(17, jdk)
      ? "${JAVA17_VERSION}"
  : "${JAVA21_VERSION}"))
}

# Return an array of Alpine platforms to use depending on the jdk passed as parameter
function "alpine_platforms" {
  params = [jdk]
  result = (equal(21, jdk)
    ? ["linux/amd64", "linux/arm64"]
  : ["linux/amd64"])
}

# Return an array of Debian platforms to use depending on the jdk passed as parameter
function "debian_platforms" {
  params = [jdk]
  result = (equal(11, jdk)
    ? ["linux/amd64", "linux/arm64", "linux/ppc64le", "linux/arm/v7", "linux/s390x"]
    : (equal(17, jdk)
      ? ["linux/amd64", "linux/arm64", "linux/ppc64le", "linux/arm/v7"]
  : ["linux/amd64", "linux/arm64", "linux/ppc64le", "linux/s390x"]))
}

target "alpine" {
  matrix = {
    type = ["agent", "inbound-agent"]
    jdk  = [11, 17, 21]
  }
  name       = "${type}_alpine_jdk${jdk}"
  target     = type
  dockerfile = "alpine/Dockerfile"
  context    = "."
  args = {
    ALPINE_TAG   = ALPINE_FULL_TAG
    VERSION      = REMOTING_VERSION
    JAVA_VERSION = "${javaversion(jdk)}"
  }
  tags = [
    # If there is a tag, add versioned tags suffixed by the jdk
    equal(ON_TAG, "true") ? "${REGISTRY}/${orgrepo(type)}:${REMOTING_VERSION}-${BUILD_NUMBER}-alpine-jdk${jdk}" : "",
    equal(ON_TAG, "true") ? "${REGISTRY}/${orgrepo(type)}:${REMOTING_VERSION}-${BUILD_NUMBER}-alpine${ALPINE_SHORT_TAG}-jdk${jdk}" : "",
    # If there is a tag and if the jdk is the default one, add Alpine short tags
    equal(ON_TAG, "true") ? (is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:${REMOTING_VERSION}-${BUILD_NUMBER}-alpine" : "") : "",
    equal(ON_TAG, "true") ? (is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:${REMOTING_VERSION}-${BUILD_NUMBER}-alpine${ALPINE_SHORT_TAG}" : "") : "",
    # If the jdk is the default one, add Alpine short tags
    is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:alpine" : "",
    is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:alpine${ALPINE_SHORT_TAG}" : "",
    is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:latest-alpine" : "",
    is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:latest-alpine${ALPINE_SHORT_TAG}" : "",
    "${REGISTRY}/${orgrepo(type)}:alpine-jdk${jdk}",
    "${REGISTRY}/${orgrepo(type)}:alpine${ALPINE_SHORT_TAG}-jdk${jdk}",
    "${REGISTRY}/${orgrepo(type)}:latest-alpine-jdk${jdk}",
    "${REGISTRY}/${orgrepo(type)}:latest-alpine${ALPINE_SHORT_TAG}-jdk${jdk}",
  ]
  platforms = alpine_platforms(jdk)
}

target "debian" {
  matrix = {
    type = ["agent", "inbound-agent"]
    jdk  = [11, 17, 21]
  }
  name       = "${type}_debian_${jdk}"
  target     = type
  dockerfile = "debian/Dockerfile"
  context    = "."
  args = {
    VERSION        = REMOTING_VERSION
    DEBIAN_RELEASE = DEBIAN_RELEASE
    JAVA_VERSION   = "${javaversion(jdk)}"
  }
  tags = [
    # If there is a tag, add versioned tag suffixed by the jdk
    equal(ON_TAG, "true") ? "${REGISTRY}/${orgrepo(type)}:${REMOTING_VERSION}-${BUILD_NUMBER}-jdk${jdk}" : "",
    # If there is a tag and if the jdk is the default one, add versioned short tag
    equal(ON_TAG, "true") ? (is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:${REMOTING_VERSION}-${BUILD_NUMBER}" : "") : "",
    # If the jdk is the default one, add Debian and latest short tags
    is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:bookworm" : "",
    is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:latest" : "",
    is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:latest-bookworm" : "",
    "${REGISTRY}/${orgrepo(type)}:bookworm-jdk${jdk}",
    "${REGISTRY}/${orgrepo(type)}:jdk${jdk}",
    "${REGISTRY}/${orgrepo(type)}:latest-bookworm-jdk${jdk}",
    "${REGISTRY}/${orgrepo(type)}:latest-jdk${jdk}",
  ]
  platforms = debian_platforms(jdk)
}

target "agent_archlinux_jdk11" {
  dockerfile = "archlinux/Dockerfile"
  context    = "."
  args = {
    JAVA_VERSION = JAVA11_VERSION
    VERSION      = REMOTING_VERSION
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${orgrepo("agent")}:${REMOTING_VERSION}-${BUILD_NUMBER}-archlinux" : "",
    equal(ON_TAG, "true") ? "${REGISTRY}/${orgrepo("agent")}:${REMOTING_VERSION}-${BUILD_NUMBER}-archlinux-jdk11" : "",
    "${REGISTRY}/${orgrepo("agent")}:archlinux",
    "${REGISTRY}/${orgrepo("agent")}:latest-archlinux",
    "${REGISTRY}/${orgrepo("agent")}:archlinux-jdk11",
    "${REGISTRY}/${orgrepo("agent")}:latest-archlinux-jdk11",
  ]
  platforms = ["linux/amd64"]
}
