Jenkins Agent Docker image
===

[![Docker Stars](https://img.shields.io/docker/stars/jenkins/slave.svg)](https://hub.docker.com/r/jenkins/slave/)
[![Docker Pulls](https://img.shields.io/docker/pulls/jenkins/slave.svg)](https://hub.docker.com/r/jenkins/slave/)
[![Docker Automated build](https://img.shields.io/docker/automated/jenkins/slave.svg)](https://hub.docker.com/r/jenkins/slave/)
[![GitHub release](https://img.shields.io/github/release/jenkinsci/docker-slave.svg?label=chanelog)](https://github.com/jenkinsci/docker-slave/releases/latest)

This is a base image for Docker, which includes OpenJDK 8 and the Jenkins agent executable (agent.jar).
This executable is an instance of the [Jenkins Remoting library](https://github.com/jenkinsci/remoting).

## Changelog

See [GitHub releases](https://github.com/jenkinsci/docker-slave/releases) for versions `3.35-1` and above.
There is no changelog for previous versions, see the commit history.

## Usage

This image is used as the basis for the [Docker JNLP Agent](https://github.com/jenkinsci/docker-jnlp-slave/) image.
In that image, the container is launched externally and attaches to Jenkins.

This image may instead be used to launch an agent using the **Launch method** of **Launch agent via execution of command on the master**. For example on Linux you can try

```sh
docker run -i --rm --name agent --init jenkins/slave java -jar /usr/share/jenkins/agent.jar
```

after setting **Remote root directory** to `/home/jenkins/agent`.

or if using Windows

```
docker run -i --rm --name agent --init jenkins/agent:latest-windows java -jar C:/ProgramData/Jenkins/agent.jar
```

after setting **Remote root directory** to `C:\Users\jenkins\Agent`.


### Agent Work Directories

Starting from [Remoting 3.8](https://github.com/jenkinsci/remoting/blob/master/CHANGELOG.md#38) there is a support of Work directories, 
which provides logging by default and change the JAR Caching behavior.

Call example for Linux:

```sh
docker run -i --rm --name agent1 --init -v agent1-workdir:/home/jenkins/agent jenkins/slave java -jar /usr/share/jenkins/agent.jar -workDir /home/jenkins/agent
```

Call example for Windows:

```
docker run -i --rm --name agent1 --init -v agent1-workdir:C:/Users/jenkins/Agent jenkins/agent:latest-windows java -jar C:/ProgramData/Jenkins/agent.jar -workDir C:/Users/jenkins/Agent
```

## Configurations

The image has several supported configurations, which can be accessed via the following tags:

* `latest`: Latest version with the newest remoting (based on `openjdk:8-jdk`)
* `latest-jdk11`: Latest version with the newest remoting and Java 11 (based on `openjdk:11-jdk`)
* `alpine`: Small image based on Alpine Linux (based on `openjdk:8-jdk-alpine`)
* `latest-windows`: Latest version with the newest remoting (based on `openjdk:8-jdk-windowsservercore-1809`)
* `latest-windows-jdk11`: Latest version with the newest remoting and Java 11 (based on `openjdk:11.0-jdk-windowsservercore-1809`)
* `2.62`: This version bundles [Remoting 2.x](https://github.com/jenkinsci/remoting#remoting-2]), which is compatible with Jenkins servers running on Java 6 (`1.609.4` and below)
* `2.62-alpine`: Small image with Remoting 2.x
* `2.62-jdk11`: Versioned image for Java 11

## Java 11 Support

Java 11 support is available in a preview mode.
Only Debian-based images and Windows images are provided right now.
(see [JENKINS-54487](https://issues.jenkins-ci.org/browse/JENKINS-54487)).
There is a probability that images for Java 11 will be changed to AdoptOpenJDK
before the final release of Java 11 support in Jenkins.
