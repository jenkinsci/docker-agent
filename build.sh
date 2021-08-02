#!/bin/bash

# reset in case getops has been used previously in the shell
OPTIND=1

target="build"
additional_args=""
build_number=""
remoting_version="4.3"
disable_env_props=0

while getopts "t:a:pn:r:b:d" opt; do
  case "$opt" in
    t)
      target=$OPTARG
      ;;
    a)
      additional_args=$OPTARG
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
  esac
done

# get us to the remaining arguments
shift $(expr $OPTIND - 1 )
if [[ $# -gt 0 ]] ; then
  target=$1
  shift
fi

if [[ "${disable_env_props}" = "0" ]] ; then
  source env.props
  export `cut -d= -f1 env.props`
fi

REPOSITORY=${DOCKERHUB_REPO:-agent}
ORGANIZATION=${DOCKERHUB_ORGANISATION:-jenkins}
remoting_version=${REMOTING_VERSION:-${remoting_version}}

if [[ "${target}" = "build" ]] ; then
  make build
fi

if [[ $? -ne 0 ]] ; then
  exit $?
fi

if [[ "${target}" = "test" ]] ; then
    make test
fi

if [[ "${target}" = "publish" ]] ; then
  set -x
  export JENKINS_REPO="${ORGANIZATION}/${REPOSITORY}"
  export REMOTING_VERSION="${remoting_version}"
  if [[ -n "${build_number}" ]] ; then
    export ON_TAG=true
    export BUILD_NUMBER=$build_number
  fi
    docker buildx bake --push --file docker-bake.hcl \
      --set '*.platform=linux/amd64' \
      linux
fi

if [[ $? -ne 0 ]] ; then
  echo "Build Failed!"
else
  echo "Build finished successfully"
fi

exit $?
