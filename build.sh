#!/bin/bash

# reset in case getops has been used previously in the shell
OPTIND=1

target="build"
additional_args=""
build=""
remoting_version="4.3"
build_number="6"
push_versions=0
disable_env_props=0

while getopts "t:a:pn:r:b:d" opt; do
  case "$opt" in
    t)
      target=$OPTARG
      ;;
    a)
      additional_args=$OPTARG
      ;;
    p)
      push_versions=1
      ;;
    n)
      build_number=$OPTARG
      ;;
    r)
      remoting_version=$OPTARG
      ;;
    b)
      build=$OPTARG
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

# this is the jdk version that will be used for the 'bare tag' images, 
# e.g., jdk8-alpine -> alpine
DEFAULT_BUILD="8"
# this is the image type that will be used for jenkins/agent:latest
DEFAULT_IMAGE="buster"
declare -A builds
build_names=()

dockerfiles=$(find . -iname Dockerfile | grep -v windows | grep -v bats)

for dockerfile in $dockerfiles ; do
  dir=$(dirname $dockerfile)
  declare $(echo $dockerfile | awk '{ split($0,a,"/"); print "jdk_version="a[2]; print "base_image="a[3]; }')
  basic_tag="${base_image}-jdk${jdk_version}"
  tags=("${basic_tag}" "latest-${basic_tag}")
  if [[ "${jdk_version}" = "${DEFAULT_BUILD}" ]] ; then
    tags+=("${base_image}")
  fi
  if [[ "${base_image}" = "${DEFAULT_IMAGE}" ]] ; then
    tags+=("latest" "jdk${jdk_version}")
  fi
  build_names+=("${basic_tag}")
  builds["${basic_tag}-folder"]=$dir
  builds["${basic_tag}-tags"]="${tags[@]}"
done

if [[ -n "${build}" && "${build_names[@]}" =~ "${build}" ]] ; then
  for tag in ${builds[$build-tags]} ; do
    echo "Building ${build} => tag=${tag}"
    docker build --build-arg VERSION="${remoting_version}" -t "${ORGANIZATION}/${REPOSITORY}:${tag}" "${builds[$build-folder]}"
    if [[ "${push_versions}" = "1" ]] ; then
      build_tag="${remoting_version}-${build_number}-${tag}"
      if [[ "${tag}" = "latest" ]] ; then
        build_tag="${remoting_version}-${build_number}"
      fi
      echo "Building ${build} => tag=${build_tag}"
      docker build --build-arg VERSION="${remoting_version}" -t "${ORGANIZATION}/${REPOSITORY}:${build_tag}" "${builds[$build-folder]}"
    fi
  done
else
  for b in "${build_names[@]}" ; do
    for tag in ${builds[$b-tags]}; do
      echo "Building ${b} => tag=${tag}"
      docker build --build-arg VERSION="${remoting_version}" -t "${ORGANIZATION}/${REPOSITORY}:${tag}" "${builds[$b-folder]}"

      if [[ "${push_versions}" = "1" ]] ; then
        build_tag="${remoting_version}-${build_number}-${tag}"
	if [[ "${tag}" = "latest" ]] ; then
          build_tag="${remoting_version}-${build_number}"
	fi
        echo "Building ${b} => tag=${build_tag}"
	docker build --build-arg VERSION="${remoting_version}" -t "${ORGANIZATION}/${REPOSITORY}:${build_tag}" "${builds[$b-folder]}"
      fi
    done
  done
fi

if [[ $? -ne 0 ]] ; then
  exit $?
fi

if [[ "${target}" = "test" ]] ; then
    make test
fi

if [[ "${target}" = "publish" ]] ; then
  if [[ -n "${build}" && "${build_names[@]}" =~ "${build}" ]] ; then
    for tag in ${builds[$build-tags]} ; do
      echo "Publishing ${build} => tag=${tag}"
      docker push "${ORGANIZATION}/${REPOSITORY}:${tag}"

      if [[ "${push_versions}" = "1" ]] ; then
        build_tag="${remoting_version}-${build_number}-${tag}"
	if [[ "${tag}" = "latest" ]]; then
          build_tag="${remoting_version}-${build_number}"
	fi
	echo "Publishing ${build} => tag=${tag}"
        docker push "${ORGANIZATION}/${REPOSITORY}:${build_tag}"
      fi
    done
  else
    for b in "${build_names[@]}" ; do
      for tag in ${builds[$b-tags]}; do
        echo "Publishing ${b} => tag=${tag}"
        docker push "${ORGANIZATION}/${REPOSITORY}:${tag}"

        if [[ "${push_versions}" = "1" ]] ; then
          build_tag="${remoting_version}-${build_number}-${tag}"
	  if [[ "${tag}" = "latest" ]] ; then
            build_tag="${remoting_version}-${build_number}"
	  fi
          echo "Publishing ${b} => tag=${build_tag}"
	  docker push "${ORGANIZATION}/${REPOSITORY}:${build_tag}"
        fi
      done
    done
  fi
fi

if [[ $? -ne 0 ]] ; then
  echo "Build Failed!"
else
  echo "Build finished successfully"
fi

exit $?
