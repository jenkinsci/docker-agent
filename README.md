# Jenkins Agent and Inbound Agent Docker images

[![Join the chat at https://gitter.im/jenkinsci/docker](https://badges.gitter.im/jenkinsci/docker.svg)](https://gitter.im/jenkinsci/docker?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![GitHub stars](https://img.shields.io/github/stars/jenkinsci/docker-agent?label=GitHub%20stars)](https://github.com/jenkinsci/docker-agent)
[![GitHub release](https://img.shields.io/github/release/jenkinsci/docker-agent.svg?label=changelog)](https://github.com/jenkinsci/docker-agent/releases/latest)

This repository contains the definition of Jenkins agent and inbound agent Docker images.

## agent
[![Docker Pulls](https://img.shields.io/docker/pulls/jenkins/agent.svg)](https://hub.docker.com/r/jenkins/agent/)

This is a base image for Docker, which includes JDK and the Jenkins agent executable (agent.jar).

See [the `agent` README](./README_agent.md)

## inbound-agent
[![Docker Pulls](https://img.shields.io/docker/pulls/jenkins/inbound-agent.svg)](https://hub.docker.com/r/jenkins/inbound-agent/)

This is an image based on `agent` for [Jenkins](https://jenkins.io) agents using TCP or WebSockets to establish inbound connection to the Jenkins controller.

See [the `inbound-agent` README](./README_inbound-agent.md)

## Building

### Building and testing on Linux

#### Target images

If you want to see the target images (matching your current architecture) that will be built, you can issue the following command:

```bash
$ make list
agent_alpine_jdk17
agent_alpine_jdk21
agent_debian_jdk17
agent_debian_jdk21
agent_rhel_ubi9_jdk17
agent_rhel_ubi9_jdk21
inbound-agent_alpine_jdk17
inbound-agent_alpine_jdk21
inbound-agent_debian_jdk17
inbound-agent_debian_jdk21
inbound-agent_rhel_ubi9_jdk17
inbound-agent_rhel_ubi9_jdk21
```

#### Building a specific image

If you want to build a specific image, you can issue the following command:

```bash
make build-<AGENT_TYPE>_<LINUX_FLAVOR>_<JDK_VERSION>
```

That would give for an image of an inbound agent with JDK 17 on Debian:

```bash
make build-inbound-agent_debian_jdk17
```

#### Building images supported by your current architecture

Then, you can build the images supported by your current architecture by running:

```bash
make build
```

#### Testing all images

If you want to test these images, you can run:

```bash
make test
```
#### Testing a specific image

If you want to test a specific image, you can run:

```bash
make test-<AGENT_TYPE>_<LINUX_FLAVOR>_<JDK_VERSION>
```

That would give for an image of an inbound agent with JDK 17 on Debian:

```bash
make test-inbound-agent_debian_jdk17
```

#### Building all images

You can build all images (even those unsupported by your current architecture) by running:

```bash
make every-build
```

#### Other `make` targets

`show` gives us a detailed view of the images that will be built, with the tags, platforms, and Dockerfiles.

```bash
$ make show
{
  "group": {
    "alpine": {
      "targets": [
        "agent_alpine_jdk17",
        "agent_alpine_jdk21",
        "inbound-agent_alpine_jdk17",
        "inbound-agent_alpine_jdk21"
      ]
    },
    "debian": {
      "targets": [
        "agent_debian_jdk17",
        "agent_debian_jdk21",
        "inbound-agent_debian_jdk17",
        "inbound-agent_debian_jdk21"
      ]
    },
    "default": {
      "targets": [
        "linux"
      ]
    },
    "linux": {
      "targets": [
        "alpine",
        "debian",
        "rhel_ubi9"
      ]
    },
    "rhel_ubi9": {
      "targets": [
        "agent_rhel_ubi9_jdk17",
        "agent_rhel_ubi9_jdk21",
        "inbound-agent_rhel_ubi9_jdk17",
        "inbound-agent_rhel_ubi9_jdk21"
      ]
    }
  },
  "target": {
    "agent_alpine_jdk17": {
      "context": ".",
      "dockerfile": "alpine/Dockerfile",
      "args": {
        "ALPINE_TAG": "3.20.3",
        "JAVA_VERSION": "17.0.12_7",
        "VERSION": "3261.v9c670a_4748a_9"
      },
      "tags": [
        "docker.io/jenkins/agent:alpine",
        "docker.io/jenkins/agent:alpine3.20",
        "docker.io/jenkins/agent:latest-alpine",
        "docker.io/jenkins/agent:latest-alpine3.20",
        "docker.io/jenkins/agent:alpine-jdk17",
        "docker.io/jenkins/agent:alpine3.20-jdk17",
        "docker.io/jenkins/agent:latest-alpine-jdk17",
        "docker.io/jenkins/agent:latest-alpine3.20-jdk17"
      ],
      "target": "agent",
      "platforms": [
        "linux/amd64"
      ],
      "output": [
        "type=docker"
      ]
    },
    [...]
```

`bats` is a dependency target. It will update the [`bats` submodule](https://github.com/bats-core/bats-core) and run the tests.

```bash
make bats
make: 'bats' is up to date.
```

`publish` allows the publication of all images targeted by 'linux' to a registry.

`docker-init` is dedicated to Jenkins infrastructure for initializing docker and isn't required in other contexts.

### Building and testing on Windows

#### Building all images

Run `.\build.ps1` to launch the build of the images corresponding to the "windows" target of docker-bake.hcl.

Internally, the first time you'll run this script and if there is no build-windows_<AGENT_TYPE>_<WINDOWS_FLAVOR>_<WINDOWS_VERSION>.yaml file in your repository, it will use a combination of `docker buildx bake` and `yq` to generate a  build-windows_<AGENT_TYPE>_<WINDOWS_FLAVOR>_<WINDOWS_VERSION>.yaml docker compose file containing all Windows image definitions from docker-bake.hcl. Then it will run `docker compose` on this file to build these images.

You can modify this docker compose file as you want, then rerun `.\build.ps1`.
It won't regenerate the docker compose file from docker-bake.hcl unless you add the `-OverwriteDockerComposeFile` build.ps1 parameter:  `.\build.ps1 -OverwriteDockerComposeFile`.

Note: you can generate this docker compose file from docker-bake.hcl yourself with the following command (require `docker buildx` and `yq`):

```console
# - Use docker buildx bake to output image definitions from the "windows" bake target
# - Convert with yq to the format expected by docker compose
# - Store the result in the docker compose file

$ docker buildx bake --progress=plain --file=docker-bake.hcl windows --print `
    | yq --prettyPrint '.target[] | del(.output) | {(. | key): {\"image\": .tags[0], \"build\": .}}' | yq '{\"services\": .}' `
    | Out-File -FilePath build-windows_mybuild.yaml
```

Note that you don't need build.ps1 to build (or to publish) your images from this docker compose file, you can use `docker compose --file=build-windows_mybuild.yaml build`.

#### Testing all images

Run `.\build.ps1 test` if you also want to run the tests harness suit.

Run `.\build.ps1 test -TestsDebug 'debug'` to also get commands & stderr of tests, displayed on top of them.
You can set it to `'verbose'` to also get stdout of every test command.

Note that instead of passing `-TestsDebug` parameter to build.ps1, you can set the  $env:TESTS_DEBUG environment variable to the desired value.

Also note that contrary to the Linux part, you have to build the images before testing them.

#### Dry run

Add the `-DryRun` parameter to print out any build, publish or tests commands instead of executing them: `.\build.ps1 test -DryRun`

#### Building and testing a specific image

You can build (and test) only one image type by setting `-ImageType` to a combination of Windows flavors ("nanoserver" & "windowsservercore") and Windows versions ("1809", "ltsc2019", "ltsc2022").

Ex: `.\build.ps1 -ImageType 'nanoserver-ltsc2019'`

Warning: trying to build `windowsservercore-1809` will fail as there is no corresponding image from Microsoft.

You can also build (and test) only one agent type by setting `-AgentType` to either "agent" or "inbound-agent".

Ex: `.\build.ps1 -AgentType 'agent'`

Both parameters can be combined.
