#!/usr/bin/env bats

AGENT_CONTAINER=bats-jenkins-jnlp-agent

load test_helpers

buildNetcatImage

SUT_IMAGE="$(get_sut_image)"

@test "[${SUT_IMAGE}] image has installed jenkins-agent in PATH" {
  local sut_cid
  sut_cid="$(docker run -d -it -P "${SUT_IMAGE}" /bin/bash)"

  is_agent_container_running "${sut_cid}"

  run docker exec "${sut_cid}" which jenkins-agent
  [ "/usr/local/bin/jenkins-agent" = "${lines[0]}" ]

  run docker exec "${sut_cid}" which jenkins-agent
  [ "/usr/local/bin/jenkins-agent" = "${lines[0]}" ]

  cleanup "${sut_cid}"
}

@test "[${SUT_IMAGE}] image starts jenkins-agent correctly (slow test)" {
  local netcat_cid sut_cid
  # Spin off a helper image which launches the netcat utility, listening at port 5000 for 30 sec
  netcat_cid="$(docker run -d -it netcat-helper:latest /bin/sh -c "timeout 30s nc -l 5000")"

  # Run jenkins agent which tries to connect to the netcat-helper container at port 5000
  sut_cid="$(docker run -d --link "${netcat_cid}" "${SUT_IMAGE}" -url "http://${netcat_cid}:5000" aaa bbb)"

  # Wait for the whole process to take place (in resource-constrained environments it can take 100s of milliseconds)
  sleep 5

  # Capture the logs output from netcat and check the header of the first HTTP request with the expected one
  run docker logs "${netcat_cid}"
  echo "${output}" | grep 'GET /tcpSlaveAgentListener/ HTTP/1.1'

  cleanup "${netcat_cid}"
  cleanup "${sut_cid}"
}

@test "[${SUT_IMAGE}] image parses \$REMOTING_OPTS correctly (slow test)" {
  local netcat_cid sut_cid
  netcat_cid="$(docker run -d -it netcat-helper:latest /bin/sh -c "while :; do (echo 'HTTP/1.1 200 OK'; echo) | nc -l 5000; done")"
  sut_cid="$(docker run -d --link "${netcat_cid}" -e REMOTING_OPTS="-url http://${netcat_cid}:5000 -name xxx -secret xxx -webSocket -webSocketHeader \"Cookie=x=1; y=2\"" "${SUT_IMAGE}")"
  sleep 5
  run docker logs "${netcat_cid}"
  echo "${output}" | grep 'Cookie:x=1; y=2'
  cleanup "${netcat_cid}"
  cleanup "${sut_cid}"
}

@test "[${SUT_IMAGE}] use build args correctly" {
  cd "${BATS_TEST_DIRNAME}"/.. || false

  local TEST_VERSION TEST_USER sut_image sut_cid

  # Old version used to test overriding the build arguments.
  TEST_VERSION="3180.v3dd999d24861"
  TEST_USER="root"

  sut_image="${SUT_IMAGE}-tests-${BATS_TEST_NUMBER}"

  docker buildx bake \
    --set "${IMAGE}.args.VERSION=${TEST_VERSION}" \
    --set "${IMAGE}.args.user=${TEST_USER}" \
    --set "${IMAGE}.platform=linux/${ARCH}" \
    --set "${IMAGE}.tags=${sut_image}" \
    --load \
      "${IMAGE}"

  sut_cid="$(docker run -d -it --name "${AGENT_CONTAINER}" -P "${sut_image}" /bin/sh)"

  is_agent_container_running "${sut_cid}"

  run docker exec "${sut_cid}" sh -c "java -jar /usr/share/jenkins/agent.jar -version"
  [ "${TEST_VERSION}" = "${lines[0]}" ]

  run docker exec "${AGENT_CONTAINER}" sh -c "id -u -n ${TEST_USER}"
  [ "${TEST_USER}" = "${lines[0]}" ]

  cleanup "${sut_cid}"
}
