#!/usr/bin/env bats

load test_helpers

REGEX='^([0-9]+)/(.+)$'

SUT_IMAGE=$(get_sut_image)

@test "[${SUT_IMAGE}] checking image metadata" {
  local VOLUMES_MAP
  VOLUMES_MAP="$(docker inspect -f '{{.Config.Volumes}}' ${SUT_IMAGE})"

  echo "${VOLUMES_MAP}" | grep '/home/jenkins/.jenkins'
  echo "${VOLUMES_MAP}" | grep '/home/jenkins/agent'
}

@test "[${SUT_IMAGE}] image has bash and java installed and in the PATH" {
  local cid
  cid="$(docker run -d -it -P "${SUT_IMAGE}" /bin/sh)"

  is_agent_container_running "${cid}"

  run docker exec "${cid}" which bash
  [ "${status}" -eq 0 ]
  run docker exec "${cid}" bash --version
  [ "${status}" -eq 0 ]
  run docker exec "${cid}" which java
  [ "${status}" -eq 0 ]

  run docker exec "${cid}" sh -c "java -version"
  [ "${status}" -eq 0 ]

  run docker exec "${cid}" sh -c "printenv | grep AGENT_WORKDIR"
  [ "AGENT_WORKDIR=/home/jenkins/agent" = "${output}" ]
}

@test "[${SUT_IMAGE}] check user access to folders" {
  local cid
  cid="$(docker run -d -it -P "${SUT_IMAGE}" /bin/sh)"

  is_agent_container_running "${cid}"

  run docker exec "${cid}" touch /home/jenkins/a
  [ "${status}" -eq 0 ]

  run docker exec "${cid}" touch /home/jenkins/.jenkins/a
  [ "${status}" -eq 0 ]

  run docker exec "${cid}" touch /home/jenkins/agent/a
  [ "${status}" -eq 0 ]
}

@test "[${SUT_IMAGE}] use build args correctly" {
  cd "${BATS_TEST_DIRNAME}"/.. || false

  local TEST_VERSION="3.36"
	local TEST_USER="test-user"
	local TEST_GROUP="test-group"
	local TEST_UID=2000
	local TEST_GID=3000
	local TEST_AGENT_WORKDIR="/home/test-user/something"
  local sut_image="${SUT_IMAGE}-tests-${BATS_TEST_NUMBER}"

  docker buildx bake ${IMAGE}
  docker build \
    --build-arg "VERSION=${TEST_VERSION}" \
    --build-arg "user=${TEST_USER}" \
    --build-arg "group=${TEST_GROUP}" \
    --build-arg "uid=${TEST_UID}" \
    --build-arg "gid=${TEST_GID}" \
    --build-arg "AGENT_WORKDIR=${TEST_AGENT_WORKDIR}" \
    -t "${sut_image}" \
    "$(get_dockerfile_directory)"

  local cid
  cid="$(docker run -d -it -P "${sut_image}" /bin/sh)"

  is_agent_container_running "${cid}"

  run docker exec "${cid}" sh -c "java -cp /usr/share/jenkins/agent.jar hudson.remoting.jnlp.Main -version"
  [ "${TEST_VERSION}" = "${lines[0]}" ]

  run docker exec "${cid}" sh -c "id -u -n ${TEST_USER}"
  [ "${TEST_USER}" = "${lines[0]}" ]

  run docker exec "${cid}" sh -c "id -g -n ${TEST_USER}"
  [ "${TEST_GROUP}" = "${lines[0]}" ]

  run docker exec "${cid}" sh -c "id -u ${TEST_USER}"
  [ "${TEST_UID}" = "${lines[0]}" ]

  run docker exec "${cid}" sh -c "id -g ${TEST_USER}"
  [ "${TEST_GID}" = "${lines[0]}" ]

  run docker exec "${cid}" sh -c "printenv | grep AGENT_WORKDIR"
  [ "AGENT_WORKDIR=/home/${TEST_USER}/something" = "${lines[0]}" ]

  run docker exec "${cid}" sh -c 'stat -c "%U:%G" "${AGENT_WORKDIR}"'
  [ "${TEST_USER}:${TEST_GROUP}" = "${lines[0]}" ]

  run docker exec "${cid}" touch /home/test-user/a
  [ "${status}" -eq 0 ]

  run docker exec "${cid}" touch /home/test-user/.jenkins/a
  [ "${status}" -eq 0 ]

  run docker exec "${cid}" touch /home/test-user/something/a
  [ "${status}" -eq 0 ]
}
