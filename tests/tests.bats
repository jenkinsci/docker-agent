#!/usr/bin/env bats

AGENT_IMAGE=jenkins-agent
AGENT_CONTAINER=bats-jenkins-agent

REGEX='^([0-9]+)/(.+)$'

if [[ ${FOLDER} =~ ${REGEX} ]] && [[ -d "${FOLDER}" ]]
then
  JDK="${BASH_REMATCH[1]}"
  FLAVOR="${BASH_REMATCH[2]}"
else
  echo "Wrong folder format or folder does not exist: ${FOLDER}"
  exit 1
fi

if [[ "${JDK}" = "11" ]]
then
  AGENT_IMAGE+=":jdk11"
  AGENT_CONTAINER+="-jdk11"
elif [[ "${FLAVOR}" = "jdk11-buster" ]]
then
  DOCKERFILE+="-jdk11-buster"
  JDK=11
  AGENT_IMAGE+=":jdk11-buster"
  AGENT_CONTAINER+="-jdk11-buster"
else
  if [[ "${FLAVOR}" = "alpine*" ]]
  then
    AGENT_IMAGE+=":alpine"
    AGENT_CONTAINER+="-alpine"
  else
    AGENT_IMAGE+=":latest"
  fi
fi

load test_helpers

clean_test_container

function teardown () {
  clean_test_container
}

@test "[${JDK} ${FLAVOR}] build image" {
  cd "${BATS_TEST_DIRNAME}"/.. || false
  docker build -t "${AGENT_IMAGE}" "${FOLDER}"
}

@test "[${JDK} ${FLAVOR}] checking image metadata" {
  local VOLUMES_MAP
  VOLUMES_MAP="$(docker inspect -f '{{.Config.Volumes}}' ${AGENT_IMAGE})"

  echo "${VOLUMES_MAP}" | grep '/home/jenkins/.jenkins'
  echo "${VOLUMES_MAP}" | grep '/home/jenkins/agent'
}

@test "[${JDK} ${FLAVOR}] image has bash and java installed and in the PATH" {
  docker run -d -it --name "${AGENT_CONTAINER}" -P "${AGENT_IMAGE}" /bin/sh

  is_agent_container_running

  run docker exec "${AGENT_CONTAINER}" which bash
  [ "${status}" -eq 0 ]
  run docker exec "${AGENT_CONTAINER}" bash --version
  [ "${status}" -eq 0 ]
  run docker exec "${AGENT_CONTAINER}" which java
  [ "${status}" -eq 0 ]

  if [[ "${JDK}" -eq 8 ]]
  then
    run docker exec "${AGENT_CONTAINER}" sh -c "
    java -version 2>&1 \
      | grep -o -E '^openjdk version \"[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+.*\"' \
      | grep -o -E '\.[[:digit:]]+\.' \
      | grep -o -E '[[:digit:]]+'
    "
  else
    run docker exec "${AGENT_CONTAINER}" sh -c "
    java -version 2>&1 \
      | grep -o -E '^openjdk version \"[[:digit:]]+\.' \
      | grep -o -E '\"[[:digit:]]+\.' \
      | grep -o -E '[[:digit:]]+'
    "
  fi
  [ "${JDK}" = "${lines[0]}" ]

  run docker exec "${AGENT_CONTAINER}" sh -c "printenv | grep AGENT_WORKDIR"
  [ "AGENT_WORKDIR=/home/jenkins/agent" = "${output}" ]
}

@test "[${JDK} ${FLAVOR}] check user access to folders" {
  docker run -d -it --name "${AGENT_CONTAINER}" -P "${AGENT_IMAGE}" /bin/sh

  is_agent_container_running

  run docker exec "${AGENT_CONTAINER}" touch /home/jenkins/a
  [ "${status}" -eq 0 ]

  run docker exec "${AGENT_CONTAINER}" touch /home/jenkins/.jenkins/a
  [ "${status}" -eq 0 ]

  run docker exec "${AGENT_CONTAINER}" touch /home/jenkins/agent/a
  [ "${status}" -eq 0 ]
}

@test "[${JDK} ${FLAVOR}] use build args correctly" {
  cd "${BATS_TEST_DIRNAME}"/.. || false

  local TEST_VERSION="3.36"
	local TEST_USER="test-user"
	local TEST_GROUP="test-group"
	local TEST_UID=2000
	local TEST_GID=3000
	local TEST_AGENT_WORKDIR="/home/test-user/something"

  docker build \
    --build-arg "VERSION=${TEST_VERSION}" \
    --build-arg "user=${TEST_USER}" \
    --build-arg "group=${TEST_GROUP}" \
    --build-arg "uid=${TEST_UID}" \
    --build-arg "gid=${TEST_GID}" \
    --build-arg "AGENT_WORKDIR=${TEST_AGENT_WORKDIR}" \
    -t "${AGENT_IMAGE}" \
    "${FOLDER}"

  docker run -d -it --name "${AGENT_CONTAINER}" -P "${AGENT_IMAGE}" /bin/sh

  is_agent_container_running

  run docker exec "${AGENT_CONTAINER}" sh -c "java -cp /usr/share/jenkins/agent.jar hudson.remoting.jnlp.Main -version"
  [ "${TEST_VERSION}" = "${lines[0]}" ]

  run docker exec "${AGENT_CONTAINER}" sh -c "id -u -n ${TEST_USER}"
  [ "${TEST_USER}" = "${lines[0]}" ]

  run docker exec "${AGENT_CONTAINER}" sh -c "id -g -n ${TEST_USER}"
  [ "${TEST_GROUP}" = "${lines[0]}" ]

  run docker exec "${AGENT_CONTAINER}" sh -c "id -u ${TEST_USER}"
  [ "${TEST_UID}" = "${lines[0]}" ]

  run docker exec "${AGENT_CONTAINER}" sh -c "id -g ${TEST_USER}"
  [ "${TEST_GID}" = "${lines[0]}" ]

  run docker exec "${AGENT_CONTAINER}" sh -c "printenv | grep AGENT_WORKDIR"
  [ "AGENT_WORKDIR=/home/${TEST_USER}/something" = "${lines[0]}" ]

  run docker exec "${AGENT_CONTAINER}" sh -c 'stat -c "%U:%G" "${AGENT_WORKDIR}"'
  [ "${TEST_USER}:${TEST_GROUP}" = "${lines[0]}" ]

  run docker exec "${AGENT_CONTAINER}" touch /home/test-user/a
  [ "${status}" -eq 0 ]

  run docker exec "${AGENT_CONTAINER}" touch /home/test-user/.jenkins/a
  [ "${status}" -eq 0 ]

  run docker exec "${AGENT_CONTAINER}" touch /home/test-user/something/a
  [ "${status}" -eq 0 ]
}
