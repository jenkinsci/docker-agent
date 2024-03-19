#!/bin/bash
set -x
set -eu -o pipefail

command -v curl >/dev/null 2>&1 || { echo "ERROR: curl command not found. Exiting."; exit 1; }

function get_jdk_download_url() {
  jdk_version="${1}"
  platform="${2}"
  case "${jdk_version}" in
    21.*)
      ENCODED_JAVA_VERSION=$(echo "$jdk_version" | jq "@uri" -jRr)
      CONVERTED_ARCH=$(arch | sed -e 's/x86_64/x64/' -e 's/armv7l/arm32/')
      echo "https://github.com/bell-sw/Liberica/releases/download/${ENCODED_JAVA_VERSION}/bellsoft-jdk${jdk_version}-linux-${CONVERTED_ARCH}-vfp-hflt"
      return 0;;
    *)
      echo "ERROR: unsupported JDK version (${jdk_version}).";
      exit 1;;
  esac
}

case "${1}" in
  21.*)
    platforms=("arm32_linux");;
  *)
    echo "ERROR: unsupported JDK version (${1}).";
    exit 1;;
esac

for platform in "${platforms[@]}"
do
  url_to_check="$(get_jdk_download_url "${1}" "${platform}")"
  if [[ "${platform}" == *windows* ]]
  then
    url_to_check+=".zip"
  else
    url_to_check+=".tar.gz"
  fi
  >&2 curl --connect-timeout 5 --location --head --fail --silent "${url_to_check}" || { echo "ERROR: the following URL is NOT available: ${url_to_check}."; exit 1; }
done

echo "OK: all JDK URL for version=${1} are available."