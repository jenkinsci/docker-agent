Jenkins Agent Docker image
===

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

```
docker run -i --rm --name agent --init jenkins/agent:jdk8-windowsservercore-1809 java -jar C:/ProgramData/Jenkins/agent.jar
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

```
docker run -i --rm --name agent1 --init -v agent1-workdir:C:/Users/jenkins/Work jenkins/agent java -jar C:/ProgramData/Jenkins/agent.jar -workDir C:/Users/jenkins/Work
```

## Configurations

The image has several supported configurations, which can be accessed via the following tags:

* `latest`: Latest version with the newest remoting (based on `openjdk:8-jdk-buster`)
* `latest-stretch`: Latest version with the newest remoting (based on `openjdk:8-jdk-stretch`)
* `latest-jdk11`: Latest version with the newest remoting and Java 11 (based on `openjdk:11-jdk-buster`)
* `alpine`: Small image based on Alpine Linux (based on `adoptopenjdk/openjdk8:jdk8u${version}-alpine`)
* `jdk8-windowsservercore-1809`: Latest version with the newest remoting (based on `adoptopenjdk:8-jdk-hotspot-windowsservercore-1809`)
* `jdk11-windowsservercore-1809`: Latest version with the newest remoting and Java 11 (based on `adoptopenjdk:11-jdk-hotspot-windowsservercore-1809`)
* `jdk8-nanoserver-1809`: Latest version with the newest remoting with Windows Nano Server
* `jdk11-nanoserver-1809`: Latest version with the newest remoting with Windows Nano Server and Java 11

There are also versioned tags in DockerHub, and they are recommended for production use.
See the full list [here](https://hub.docker.com/r/jenkins/agent/tags)

## Java 11 Support

Java 11 support is available for Debian-based images and Windows images.
Alpine image for Java 11 will not be provided, see [JENKINS-54487](https://issues.jenkins-ci.org/browse/JENKINS-54487).
There is a probability that images for Java 11 will be changed to AdoptOpenJDK base images in the future.
