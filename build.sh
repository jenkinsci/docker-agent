#!/bin/bash

set -u -o pipefail

# reset in case getops has been used previously in the shell
OPTIND=1

target="build"
build_number="1"
remoting_version="3131.vf2b_b_798b_ce99"
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

REPOSITORY=${DOCKERHUB_REPO:-agent}
ORGANIZATION=${DOCKERHUB_ORGANISATION:-jenkins}
remoting_version=${REMOTING_VERSION:-${remoting_version}}

if [[ "${target}" = "build" ]] ; then
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
  export JENKINS_REPO="${ORGANIZATION}/${REPOSITORY}"
  export REMOTING_VERSION="${remoting_version}"
  if [[ -n "${build_number}" ]] ; then
    export ON_TAG=true
    export BUILD_NUMBER=$build_number
  fi
  docker buildx bake --push --file docker-bake.hcl linux
  exit_result=$?
fi
exit_if_error

echo "Build finished successfully"
exit 0
