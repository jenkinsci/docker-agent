group "linux" {
  targets = [
    # "alpine",
    "debian",
    # "rhel_ubi9"
  ]
}

group "windows" {
  targets = [
    "nanoserver",
    "windowsservercore"
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
  default = [17, 21, 25]
}
variable "default_jdk" {
  default = 17
}

variable "jdks_in_preview" {
  default = []
}

variable "JAVA17_VERSION" {
  default = "17.0.16_8"
}

variable "JAVA21_VERSION" {
  default = "21.0.8_9"
}

variable "JAVA25_VERSION" {
  default = "25_36"
}

variable "REMOTING_VERSION" {
  default = "3345.v03dee9b_f88fc"
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
  default = "3.22.1"
}

variable "ALPINE_SHORT_TAG" {
  default = regex_replace(ALPINE_FULL_TAG, "\\.\\d+$", "")
}

variable "DEBIAN_RELEASE" {
  default = "trixie-20250929"
}

variable "UBI9_TAG" {
  default = "9.6-1758184894"
}

# Set this value to a specific Windows version to override Windows versions to build returned by windowsversions function
variable "WINDOWS_VERSION_OVERRIDE" {
  default = ""
}

# Set this value to a specific agent type to override agent type to build returned by windowsagenttypes function
variable "WINDOWS_AGENT_TYPE_OVERRIDE" {
  default = ""
}

variable "jdk_versions" {
  default = {
    17 = JAVA17_VERSION
    21 = JAVA21_VERSION
    25 = JAVA25_VERSION
  }
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
  result = lookup(jdk_versions, jdk, "Unsupported JDK version")
}

## Specific functions
# Return an array of Alpine platforms to use depending on the jdk passed as parameter
function "alpine_platforms" {
  params = [jdk]
  result = (equal(17, jdk)
    ? ["linux/amd64"]
  : ["linux/amd64", "linux/arm64"])
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

# Return the distribution followed by a dash if it is not the default distribution
function distribution_prefix {
  params = [distribution]
  result = (equal("debian", distribution)
    ? ""
  : "${distribution}-")
}

# Return a dash followed by the distribution if it is not the default distribution
function distribution_suffix {
  params = [distribution]
  result = (equal("debian", distribution)
    ? ""
  : "-${distribution}")
}

# Return the official name of the default distribution
function distribution_name {
  params = [distribution]
  result = (equal("debian", distribution)
    ? "trixie"
  : distribution)
}

# Return the tag suffixed by "-preview" if the jdk passed as parameter is in the jdks_in_preview list
function preview_tag {
  params = [jdk]
  result = (contains(jdks_in_preview, jdk)
    ? "${jdk}-preview"
  : jdk)
}

# Return an array of tags depending on the agent type, the jdk and the Linux distribution passed as parameters
function "linux_tags" {
  params = [type, jdk, distribution]
  result = [
    ## All
    # If there is a tag, add versioned tag suffixed by the jdk
    equal(ON_TAG, "true") ? "${REGISTRY}/${orgrepo(type)}:${REMOTING_VERSION}-${BUILD_NUMBER}${distribution_suffix(distribution)}-jdk${preview_tag(jdk)}" : "",

    # If there is a tag and if the jdk is the default one, add versioned short tag
    equal(ON_TAG, "true") ? (is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:${REMOTING_VERSION}-${BUILD_NUMBER}${distribution_suffix(distribution)}" : "") : "",

    # If the jdk is the default one, add distribution and latest short tags
    is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:${distribution_name(distribution)}" : "",
    is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:latest${distribution_suffix(distribution)}" : "",
    # Needed for the ":latest-trixie" case. For other distributions, result in the same tag as above (not an issue, deduplicated at the end)
    is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:latest-${distribution_name(distribution)}" : "",

    # Tags always added
    "${REGISTRY}/${orgrepo(type)}:${distribution_name(distribution)}-jdk${preview_tag(jdk)}",
    "${REGISTRY}/${orgrepo(type)}:latest-${distribution_name(distribution)}-jdk${preview_tag(jdk)}",
    # ":jdkN" and ":latest-jdkN" short tags for the default distribution. For other distributions, result in the tags above (not an issue, deduplicated at the end)
    "${REGISTRY}/${orgrepo(type)}:${distribution_prefix(distribution)}jdk${preview_tag(jdk)}",
    "${REGISTRY}/${orgrepo(type)}:latest-${distribution_prefix(distribution)}jdk${preview_tag(jdk)}",
  ]
}

# Return an array of tags depending on the agent type, the jdk and the flavor and version of Windows passed as parameters
function "windows_tags" {
  params = [type, jdk, flavor_and_version]
  result = [
    # If there is a tag, add versioned tag containing the jdk
    equal(ON_TAG, "true") ? "${REGISTRY}/${orgrepo(type)}:${REMOTING_VERSION}-${BUILD_NUMBER}-jdk${preview_tag(jdk)}-${flavor_and_version}" : "",
    # If there is a tag and if the jdk is the default one, add versioned and short tags
    equal(ON_TAG, "true") ? (is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:${REMOTING_VERSION}-${BUILD_NUMBER}-${flavor_and_version}" : "") : "",
    equal(ON_TAG, "true") ? (is_default_jdk(jdk) ? "${REGISTRY}/${orgrepo(type)}:${flavor_and_version}" : "") : "",
    "${REGISTRY}/${orgrepo(type)}:jdk${preview_tag(jdk)}-${flavor_and_version}",
  ]
}

target "_common" {
  annotations = [
    "org.opencontainers.image.vendor=Jenkins project",
    "org.opencontainers.image.url=https://www.jenkins.io/",
    "org.opencontainers.image.source=https://github.com/jenkinsci/docker-agent",
    "org.opencontainers.image.licenses=MIT"
  ]
  # attest = [
  #   "type=provenance,mode=max",
  #   "type=sbom"
  # ]
}

target "alpine" {
  inherits = ["_common"]
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
  tags      = concat(linux_tags(type, jdk, "alpine"), linux_tags(type, jdk, "alpine${ALPINE_SHORT_TAG}"))
  platforms = alpine_platforms(jdk)
}

target "debian" {
  inherits = ["_common"]
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
  tags      = linux_tags(type, jdk, "debian")
  platforms = debian_platforms(jdk)
}

target "rhel_ubi9" {
  inherits = ["_common"]
  matrix = {
    type = agent_types_to_build
    jdk  = jdks_to_build
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
  tags      = linux_tags(type, jdk, "rhel-ubi9")
  platforms = rhel_ubi9_platforms(jdk)
}

target "nanoserver" {
  inherits = ["_common"]
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
  target    = type
  tags      = windows_tags(type, jdk, "nanoserver-${windows_version}")
  platforms = ["windows/amd64"]
}

target "windowsservercore" {
  inherits = ["_common"]
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
  target    = type
  tags      = windows_tags(type, jdk, "windowsservercore-${windows_version}")
  platforms = ["windows/amd64"]
}
