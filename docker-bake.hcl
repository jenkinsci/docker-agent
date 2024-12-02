group "linux" {
  targets = [
    "alpine",
    "debian",
    "rhel_ubi9"
  ]
}

group "windows" {
  targets = [
    "nanoserver",
    "windowsservercore"
  ]
}

group "linux-agent-only" {
  targets = [
    "agent_alpine_jdk17",
    "agent_alpine_jdk21",
    "agent_debian_jdk17",
    "agent_debian_jdk21",
    "agent_rhel_ubi9_jdk17",
    "agent_rhel_ubi9_jdk21"
  ]
}

group "linux-inbound-agent-only" {
  targets = [
    "inbound-agent_alpine_jdk17",
    "inbound-agent_alpine_jdk21",
    "inbound-agent_debian_jdk17",
    "inbound-agent_debian_jdk21",
    "inbound-agent_rhel_ubi9_jdk17",
    "inbound-agent_rhel_ubi9_jdk21"
  ]
}

group "linux-arm64" {
  targets = [
    "alpine_jdk21",
    "debian",
    "rhel_ubi9"
  ]
}

group "linux-arm32" {
  targets = [
    "debian_jdk17"
  ]
}

group "linux-s390x" {
  targets = [
    "debian_jdk21"
  ]
}

group "linux-ppc64le" {
  targets = [
    "debian",
    "rhel_ubi9"
  ]
}

variable "agent_types_to_build" {
  default = ["agent", "inbound-agent"]
}

variable "jdks_to_build" {
  default = [17, 21]
}

variable "default_jdk" {
  default = 17
}

variable "JAVA17_VERSION" {
  default = "17.0.13_11"
}

variable "JAVA21_VERSION" {
  default = "21.0.5_11"
}

variable "REMOTING_VERSION" {
  default = "3283.v92c105e0f819"
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
  default = "3.20.3"
}

variable "ALPINE_SHORT_TAG" {
  default = regex_replace(ALPINE_FULL_TAG, "\\.\\d+$", "")
}

variable "DEBIAN_RELEASE" {
  default = "bookworm-20241111"
}

variable "UBI9_TAG" {
  default = "9.5-1732804088"
}

# Set this value to a specific Windows version to override Windows versions to build returned by windowsversions function
variable "WINDOWS_VERSION_OVERRIDE" {
  default = ""
}

# Set this value to a specific agent type to override agent type to build returned by windowsagenttypes function
variable "WINDOWS_AGENT_TYPE_OVERRIDE" {
  default = ""
}

## Common functions
# Return the registry organization and repository depending on the agent type
function "orgrepo" {
  params = [agentType]
  result = equal("agent", agentType) ? "${REGISTRY_ORG}/${REGISTRY_REPO_AGENT}" : "${REGISTRY_ORG}/${REGISTRY_REPO_INBOUND_AGENT}"
}

# Return "true" if the jdk passed as parameter is the same as the default jdk, "false" otherwise
function "is_default_jdk" {
  params = [jdk]
  result = equal(default_jdk, jdk) ? true : false
}

# Return the complete Java version corresponding to the jdk passed as parameter
function "javaversion" {
  params = [jdk]
  result = (equal(17, jdk)
    ? "${JAVA17_VERSION}"
  : "${JAVA21_VERSION}")
}

## Specific functions
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
  result = (equal(17, jdk)
    ? ["linux/amd64", "linux/arm64", "linux/ppc64le", "linux/arm/v7"]
  : ["linux/amd64", "linux/arm64", "linux/ppc64le", "linux/s390x"])
}

# Return array of Windows version(s) to build
# There is no mcr.microsoft.com/windows/servercore:1809 image
# Can be overriden by setting WINDOWS_VERSION_OVERRIDE to a specific Windows version
# Ex: WINDOWS_VERSION_OVERRIDE=1809 docker buildx bake windows
function "windowsversions" {
  params = [flavor]
  result = (notequal(WINDOWS_VERSION_OVERRIDE, "")
    ? [WINDOWS_VERSION_OVERRIDE]
    : (equal(flavor, "windowsservercore")
      ? ["ltsc2019", "ltsc2022"]
  : ["1809", "ltsc2019", "ltsc2022"]))
}

# Return array of agent type(s) to build
# Can be overriden to a specific agent type
function "windowsagenttypes" {
  params = [override]
  result = (notequal(override, "")
    ? [override]
  : agent_types_to_build)
}

# Return the Windows version to use as base image for the Windows version passed as parameter
# There is no mcr.microsoft.com/powershell ltsc2019 base image, using a "1809" instead
function "toolsversion" {
  params = [version]
  result = (equal("ltsc2019", version)
    ? "1809"
  : version)
}

# Return an array of RHEL UBI 9 platforms to use depending on the jdk passed as parameter
# Note: Jenkins controller container image only supports jdk17 and jdk21 for ubi9
function "rhel_ubi9_platforms" {
  params = [jdk]
  result = ["linux/amd64", "linux/arm64", "linux/ppc64le"]
}

target "alpine" {
  matrix = {
    type = agent_types_to_build
    jdk  = jdks_to_build
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
    type = agent_types_to_build
    jdk  = jdks_to_build
  }
  name       = "${type}_debian_jdk${jdk}"
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

target "rhel_ubi9" {
  matrix = {
    type = agent_types_to_build
    jdk  = [17, 21]
  }
  name       = "${type}_rhel_ubi9_jdk${jdk}"
  target     = type
  dockerfile = "rhel/ubi9/Dockerfile"
  context    = "."
  args = {
    UBI9_TAG     = UBI9_TAG
    VERSION      = REMOTING_VERSION
    JAVA_VERSION = "${javaversion(jdk)}"
  }
  tags = [
    # If there is a tag, add versioned tag suffixed by the jdk
    equal(ON_TAG, "true") ? "${REGISTRY}/${orgrepo(type)}:${REMOTING_VERSION}-${BUILD_NUMBER}-rhel-ubi9-jdk${jdk}" : "",
    # If there is a tag and if the jdk is the default one, add versioned short tag
    equal(ON_TAG, "true") ? (is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:${REMOTING_VERSION}-${BUILD_NUMBER}-rhel-ubi9" : "") : "",
    # If the jdk is the default one, add rhel and latest short tags
    is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:rhel-ubi9" : "",
    is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:latest-rhel-ubi9" : "",
    "${REGISTRY}/${orgrepo(type)}:rhel-ubi9-jdk${jdk}",
    "${REGISTRY}/${orgrepo(type)}:latest-rhel-ubi9-jdk${jdk}",
  ]
  platforms = rhel_ubi9_platforms(jdk)
}

target "nanoserver" {
  matrix = {
    type            = windowsagenttypes(WINDOWS_AGENT_TYPE_OVERRIDE)
    jdk             = jdks_to_build
    windows_version = windowsversions("nanoserver")
  }
  name       = "${type}_nanoserver-${windows_version}_jdk${jdk}"
  dockerfile = "windows/nanoserver/Dockerfile"
  context    = "."
  args = {
    JAVA_HOME             = "C:/openjdk-${jdk}"
    JAVA_VERSION          = "${replace(javaversion(jdk), "_", "+")}"
    TOOLS_WINDOWS_VERSION = "${toolsversion(windows_version)}"
    VERSION               = REMOTING_VERSION
    WINDOWS_VERSION_TAG   = windows_version
  }
  target = type
  tags = [
    # If there is a tag, add versioned tag containing the jdk
    equal(ON_TAG, "true") ? "${REGISTRY}/${orgrepo(type)}:${REMOTING_VERSION}-${BUILD_NUMBER}-jdk${jdk}-nanoserver-${windows_version}" : "",
    # If there is a tag and if the jdk is the default one, add versioned and short tags
    equal(ON_TAG, "true") ? (is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:${REMOTING_VERSION}-${BUILD_NUMBER}-nanoserver-${windows_version}" : "") : "",
    equal(ON_TAG, "true") ? (is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:nanoserver-${windows_version}" : "") : "",
    "${REGISTRY}/${orgrepo(type)}:jdk${jdk}-nanoserver-${windows_version}",
  ]
  platforms = ["windows/amd64"]
}

target "windowsservercore" {
  matrix = {
    type            = windowsagenttypes(WINDOWS_AGENT_TYPE_OVERRIDE)
    jdk             = jdks_to_build
    windows_version = windowsversions("windowsservercore")
  }
  name       = "${type}_windowsservercore-${windows_version}_jdk${jdk}"
  dockerfile = "windows/windowsservercore/Dockerfile"
  context    = "."
  args = {
    JAVA_HOME             = "C:/openjdk-${jdk}"
    JAVA_VERSION          = "${replace(javaversion(jdk), "_", "+")}"
    TOOLS_WINDOWS_VERSION = "${toolsversion(windows_version)}"
    VERSION               = REMOTING_VERSION
    WINDOWS_VERSION_TAG   = windows_version
  }
  target = type
  tags = [
    # If there is a tag, add versioned tag containing the jdk
    equal(ON_TAG, "true") ? "${REGISTRY}/${orgrepo(type)}:${REMOTING_VERSION}-${BUILD_NUMBER}-jdk${jdk}-windowsservercore-${windows_version}" : "",
    # If there is a tag and if the jdk is the default one, add versioned and short tags
    equal(ON_TAG, "true") ? (is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:${REMOTING_VERSION}-${BUILD_NUMBER}-windowsservercore-${windows_version}" : "") : "",
    equal(ON_TAG, "true") ? (is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:windowsservercore-${windows_version}" : "") : "",
    "${REGISTRY}/${orgrepo(type)}:jdk${jdk}-windowsservercore-${windows_version}",
  ]
  platforms = ["windows/amd64"]
}
