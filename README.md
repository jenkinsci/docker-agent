# Jenkins Agent Docker image

[![Join the chat at https://gitter.im/jenkinsci/docker](https://badges.gitter.im/jenkinsci/docker.svg)](https://gitter.im/jenkinsci/docker?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![GitHub stars](https://img.shields.io/github/stars/jenkinsci/docker-agent?label=GitHub%20stars)](https://github.com/jenkinsci/docker-agent)
[![Docker Pulls](https://img.shields.io/docker/pulls/jenkins/agent.svg)](https://hub.docker.com/r/jenkins/agent/)
[![GitHub release](https://img.shields.io/github/release/jenkinsci/docker-agent.svg?label=changelog)](https://github.com/jenkinsci/docker-agent/releases/latest)

This is a base image for Docker, which includes JDK and the Jenkins agent executable (agent.jar).
This executable is an instance of the [Jenkins Remoting library](https://github.com/jenkinsci/remoting).
JDK version depends on the image and the platform, see the _Configurations_ section below.

:exclamation: **Warning!** This image used to be published as [jenkinsci/slave](https://hub.docker.com/r/jenkinsci/slave/) and [jenkins/slave](https://hub.docker.com/r/jenkins/slave/).
These images are now deprecated, use [jenkins/agent](https://hub.docker.com/r/jenkins/agent/).

## Changelog

See [GitHub releases](https://github.com/jenkinsci/docker-agent/releases) for versions `3.35-1` and above.
There is no changelog for previous versions, see the commit history.

Jenkins remoting changelogs are available [here](https://github.com/jenkinsci/remoting/releases).

## Usage

This image is used as the basis for the [Docker Inbound Agent](https://github.com/jenkinsci/docker-inbound-agent/) image.
In that image, the container is launched externally and attaches to Jenkins.

This image may instead be used to launch an agent using the **Launch method** of **Launch agent via execution of command on the master**. For example on Linux you can try

```sh
docker run -i --rm --name agent --init jenkins/agent java -jar /usr/share/jenkins/agent.jar
```

after setting **Remote root directory** to `/home/jenkins/agent`.

or if using Windows Containers

```powershell
docker run -i --rm --name agent --init jenkins/agent:jdk11-windowsservercore-ltsc2019 java -jar C:/ProgramData/Jenkins/agent.jar
```

after setting **Remote root directory** to `C:\Users\jenkins\Agent`.

### Agent Work Directories

Starting from [Remoting 3.8](https://github.com/jenkinsci/remoting/blob/master/CHANGELOG.md#38) there is a support of Work directories,
which provides logging by default and change the JAR Caching behavior.

Call example for Linux:

```sh
docker run -i --rm --name agent1 --init -v agent1-workdir:/home/jenkins/agent jenkins/agent java -jar /usr/share/jenkins/agent.jar -workDir /home/jenkins/agent
```

Call example for Windows Containers:

```powershell
docker run -i --rm --name agent1 --init -v agent1-workdir:C:/Users/jenkins/Work jenkins/agent:jdk11-windowsservercore-ltsc2019 java -jar C:/ProgramData/Jenkins/agent.jar -workDir C:/Users/jenkins/Work
```

## Configurations

The image has several supported configurations, which can be accessed via the following tags:

* Linux Images:
  * `latest` (`jdk11`, `bullseye-jdk11`, `latest-bullseye-jdk11`, `latest-jdk11`): Latest version with the newest remoting and Java 11 (based on `debian:bullseye-${builddate}`)
  * `latest-jdk8` (`jdk8`, `bullseye-jdk8`, `latest-bullseye-jdk8`): Latest version with the newest remoting (based on `debian:bullseye-${builddate}`)
  * `alpine` (`alpine-jdk11`, `latest-alpine`, `latest-alpine-jdk11`): Small image based on Alpine Linux (based on `alpine:${version}`)
  * `alpine-jdk8` (`latest-alpine-jdk8`): Small image based on Alpine Linux (based on `alpine:${version}`)
  * `archlinux` (`latest-archlinux`, `archlinux-jdk11`, `latest-archlinux-jdk11`): Image based on Arch Linux with JDK11 (based on `archlinux:latest`)
  * `bullseye-jdk17-preview` (`jdk17-preview`, `latest-bullseye-jdk17-preview`, `latest-jdk17-preview`): Preview JDK17 version with the newest remoting (based on `debian:bullseye-${builddate}`)

* Windows Images:
  * `jdk8-windowsservercore-1809`: Latest version with the newest remoting and Java 8 (based on `eclipse-temurin:8.xxx-jdk-windowsservercore-1809`)
  * `jdk8-nanoserver-1809`: Latest version with the newest remoting with Windows Nano Server and Java 8 (based on `eclipse-temurin:8.xxx-jdk-nanoserver-1809`)
  * `jdk11-windowsservercore-1809`: Latest version with the newest remoting and Java 11 (based on `eclipse-temurin:11.xxx-jdk-windowsservercore-1809`)
  * `jdk11-nanoserver-1809`: Latest version with the newest remoting with Windows Nano Server and Java 11 (based on `eclipse-temurin:11.xxx-jdk-nanoserver-1809`)
  * `jdk17-windowsservercore-1809`: Latest version with the newest remoting and Java 17 (based on `eclipse-temurin:17.xxx-jdk-windowsservercore-1809`)
  * `jdk17-nanoserver-1809`: Latest version with the newest remoting with Windows Nano Server and Java 17 (based on `eclipse-temurin:17.xxx-jdk-nanoserver-1809`)

The file `docker-bake.hcl` defines all the configuration for Linux images and their associated tags.

There are also versioned tags in DockerHub, and they are recommended for production use.
See the full list [here](https://hub.docker.com/r/jenkins/agent/tags)
