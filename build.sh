#!/bin/bash

set -u -o pipefail

# reset in case getops has been used previously in the shell
OPTIND=1

target="build"
build_number="1"
remoting_version="3206.vb_15dcf73f6a_9"
disable_env_props=0
exit_result=0

function exit_if_error() {
  if [[ "$exit_result" != "0" ]]
  then
    echo "Build Failed!"
    exit $exit_result
  fi
}

while getopts "t:r:b:d" opt; do
  case "$opt" in
    t)
      target=$OPTARG
      ;;
    r)
      remoting_version=$OPTARG
      ;;
    b)
      build_number=$OPTARG
      ;;
    d)
      disable_env_props=1
      ;;
    *)
      echo "Invalid flag passed: '${opt}'."
      ;;
  esac
done

# get us to the remaining arguments
shift "$((OPTIND - 1 ))"
if [[ $# -gt 0 ]] ; then
  target=$1
  shift
fi

if [[ "${disable_env_props}" = "0" ]] ; then
  source env.props
  export "$(cut -d= -f1 env.props)"
fi

export REGISTRY_ORG=${DOCKERHUB_ORGANISATION:-jenkins4eval}
export REGISTRY_REPO_AGENT=${DOCKERHUB_REPO_AGENT:-agent}
export REGISTRY_REPO_INBOUND_AGENT=${DOCKERHUB_REPO_INBOUND_AGENT:-inbound-agent}
remoting_version=${REMOTING_VERSION:-${remoting_version}}

if [[ "${target}" = "build" ]] ; then
  make show
  make build
  exit_result=$?
  exit_if_error
fi

test $exit_result -eq 0 || exit

if [[ "${target}" = "test" ]] ; then
  make test
  exit_result=$?
  exit_if_error
fi

if [[ "${target}" = "publish" ]] ; then
  set -x
  export REMOTING_VERSION="${remoting_version}"
  if [[ -n "${build_number}" ]] ; then
    export ON_TAG=true
    export BUILD_NUMBER=$build_number
  fi
  make show
  docker buildx bake --push --file docker-bake.hcl linux
  exit_result=$?
fi
exit_if_error

echo "Build finished successfully"
exit 0
