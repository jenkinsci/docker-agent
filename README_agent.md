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

This image may instead be used to launch an agent using the **Launch method** of **Launch agent via execution of command on the controller**. For example on Linux you can try

```sh
docker run -i --rm --name agent --init jenkins/agent java -jar /usr/share/jenkins/agent.jar
```

after setting **Remote root directory** to `/home/jenkins/agent`.

or if using Windows Containers

```powershell
docker run -i --rm --name agent --init jenkins/agent:jdk17-windowsservercore-ltsc2019 java -jar C:/ProgramData/Jenkins/agent.jar
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
  * `latest` (`jdk17`, `bookworm-jdk17`, `latest-bookworm`, `latest-bookworm-jdk17`, `latest-jdk17`): Latest version with the newest remoting and JDK17 (based on `debian:bookworm-${builddate}`)
  * `alpine` (`alpine-jdk17`, `latest-alpine`, `latest-alpine-jdk17`): Small image based on Alpine Linux with JDK17 (based on `alpine:${version}`)
  * `archlinux` (`archlinux-jdk11`, `latest-archlinux`, `latest-archlinux-jdk11`): Image based on Arch Linux with JDK11 (based on `archlinux:latest`)
  * `bookworm-jdk11` (`latest-bookworm-jdk11`, `latest-jdk11`): JDK11 version with the newest remoting (based on `debian:bookworm-${builddate}`)
  * `alpine-jdk11` (`latest-alpine-jdk11`): Small image based on Alpine Linux with JDK11 (based on `alpine:${version}`)

From version 4.11.2, the alpine images are tagged using the alpine OS version as well (i.e. `alpine` ==> `alpine3.16`, `alpine-jdk11` ==> `alpine3.16-jdk11`).

* Windows Images:
  * JDK11:
    * `jdk11-nanoserver-1809`: Latest version with the newest remoting with Windows Nano Server and Java 11 (based on `mcr.microsoft.com/windows/nanoserver:1809` and `eclipse-temurin:11.xxx-jdk-nanoserver-1809`)
    * `jdk11-nanoserver-ltsc2019`: Latest version with the newest remoting with Windows Nano Server and Java 11 (based on `mcr.microsoft.com/windows/nanoserver:ltsc2019` and `eclipse-temurin:11.xxx-jdk-nanoserver-1809`)
    * `jdk11-nanoserver-ltsc2022`: Latest version with the newest remoting with Windows Nano Server and Java 11 (based on `mcr.microsoft.com/windows/nanoserver:ltsc2022` and `eclipse-temurin:11.xxx-jdk-nanoserver-ltsc2022`)
    * `jdk11-windowsservercore-1809`: Latest version with the newest remoting and Java 11 (based on `mcr.microsoft.com/windows/servercore:1809` and `eclipse-temurin:11.xxx-jdk-windowsservercore-1809`)
    * `jdk11-windowsservercore-ltsc2019`: Latest version with the newest remoting and Java 11 (based on `mcr.microsoft.com/windows/servercore:ltsc2019` and `eclipse-temurin:11.xxx-jdk-windowsservercore-1809`)
    * `jdk11-windowsservercore-ltsc2022`: Latest version with the newest remoting and Java 11 (based on `mcr.microsoft.com/windows/servercore:ltsc2022` and `eclipse-temurin:11.xxx-jdk-windowsservercore-ltsc2022`)
  * JDK17 (default):
    * `jdk17-nanoserver-1809` (`nanoserver-1809`): Latest version with the newest remoting with Windows Nano Server and Java 17 (based on `mcr.microsoft.com/windows/nanoserver:1809` and `eclipse-temurin:17.xxx-jdk-nanoserver-1809`)
    * `jdk17-nanoserver-ltsc2019` (`nanoserver-ltsc2019`): Latest version with the newest remoting with Windows Nano Server and Java 17 (based on `mcr.microsoft.com/windows/nanoserver:ltsc2019` and `eclipse-temurin:17.xxx-jdk-nanoserver-1809`)
    * `jdk17-nanoserver-ltsc2022` (`nanoserver-ltsc2022`): Latest version with the newest remoting with Windows Nano Server and Java 17 (based on `mcr.microsoft.com/windows/nanoserver:ltsc2022` and `eclipse-temurin:17.xxx-jdk-nanoserver-ltsc2022`)
    * `jdk17-windowsservercore-1809` (`windowsservercore-1809`): Latest version with the newest remoting and Java 17 (based on `mcr.microsoft.com/windows/servercore:1809` and `eclipse-temurin:17.xxx-jdk-windowsservercore-1809`)
    * `jdk17-windowsservercore-ltsc2019` (`windowsservercore-ltsc2019`): Latest version with the newest remoting and Java 17 (based on `mcr.microsoft.com/windows/servercore:ltsc2019` and `eclipse-temurin:17.xxx-jdk-windowsservercore-1809`)
    * `jdk17-windowsservercore-ltsc2022` (`windowsservercore-ltsc2022`): Latest version with the newest remoting and Java 17 (based on `mcr.microsoft.com/windows/servercore:ltsc2022` and `eclipse-temurin:17.xxx-jdk-windowsservercore-ltsc2022`)
  * JDK21:
    * `jdk21-nanoserver-1809`: Latest version with the newest remoting with Windows Nano Server and Java 21 (based on `mcr.microsoft.com/windows/nanoserver:1809` and `eclipse-temurin:21.xxx-jdk-nanoserver-1809`)
    * `jdk21-nanoserver-ltsc2019`: Latest version with the newest remoting with Windows Nano Server and Java 21 (based on `mcr.microsoft.com/windows/nanoserver:ltsc2019` and `eclipse-temurin:21.xxx-jdk-nanoserver-1809`)
    * `jdk21-nanoserver-ltsc2022`: Latest version with the newest remoting with Windows Nano Server and Java 21 (based on `mcr.microsoft.com/windows/nanoserver:ltsc2022` and `eclipse-temurin:21.xxx-jdk-nanoserver-ltsc2022`)
    * `jdk21-windowsservercore-1809`: Latest version with the newest remoting and Java 21 (based on `mcr.microsoft.com/windows/servercore:1809` and `eclipse-temurin:21.xxx-jdk-windowsservercore-1809`)
    * `jdk21-windowsservercore-ltsc2019`: Latest version with the newest remoting and Java 21 (based on `mcr.microsoft.com/windows/servercore:ltsc2019` and `eclipse-temurin:21.xxx-jdk-windowsservercore-1809`)
    * `jdk21-windowsservercore-ltsc2022`: Latest version with the newest remoting and Java 21 (based on `mcr.microsoft.com/windows/servercore:ltsc2022` and `eclipse-temurin:21.xxx-jdk-windowsservercore-ltsc2022`)

The file `docker-bake.hcl` defines all the configuration for Linux images and their associated tags.

There are also versioned tags in DockerHub, and they are recommended for production use.
See the full list [here](https://hub.docker.com/r/jenkins/agent/tags)

## Timezones

### Using directly the `jenkins/agent` image

By default, the image is using the `Etc/UTC` timezone.
If you want to use the timezone of your machine, you can mount the `/etc/localtime` file from the host (as per [this comment](https://github.com/moby/moby/issues/12084#issuecomment-89697533)) and the `/etc/timezone` from the host too.
In this example, the machine is using the `Europe/Paris` timezone.

```bash
docker run --rm --tty --interactive --entrypoint=date --volume=/etc/localtime:/etc/localtime:ro --volume=/etc/timezone:/etc/timezone:ro jenkins/agent
Fri Nov 25 18:27:22 CET 2022
```

You can also set the `TZ` environment variable to the desired timezone.
`TZ` is a standard POSIX environment variable used by many images, see [Wikipedia](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) for a list of valid values.
The next command is run on a machine using the `Europe/Paris` timezone a few seconds after the previous one.

```bash
docker run --rm --tty --interactive --env TZ=Asia/Shanghai --entrypoint=date jenkins/agent
Sat Nov 26 01:27:58 CST 2022 
```

### Using the `jenkins/agent` image as a base image

Should you want to adapt the `jenkins/agent` image to your local timezone while creating your own image based on it, you could use the following command (inspired by issue #[291](https://github.com/jenkinsci/docker-inbound-agent/issues/291)):

```dockerfile
FROM jenkins/agent as agent
 [...]
ENV TZ=Asia/Shanghai
 [...]
RUN ln -snf /usr/share/zoneinfo/"${TZ}" /etc/localtime && echo "${TZ}" > /etc/timezone \
    && dpkg-reconfigure -f noninteractive tzdata \
 [...] 
```
