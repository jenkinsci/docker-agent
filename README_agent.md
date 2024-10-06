# Jenkins Agent Docker image

[![Join the chat at https://gitter.im/jenkinsci/docker](https://badges.gitter.im/jenkinsci/docker.svg)](https://gitter.im/jenkinsci/docker?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![Docker Pulls](https://img.shields.io/docker/pulls/jenkins/agent.svg)](https://hub.docker.com/r/jenkins/agent/)
[![GitHub release](https://img.shields.io/github/release/jenkinsci/docker-agent.svg?label=changelog)](https://github.com/jenkinsci/docker-agent/releases/latest)

This is a base image for Docker, which includes Java and the Jenkins agent executable (agent.jar).
This executable is an instance of the [Jenkins Remoting library](https://github.com/jenkinsci/remoting).
Java version depends on the image and the platform, see the _Configurations_ section below.

## Usage

This image is used as the basis for the [Docker Inbound Agent](https://github.com/jenkinsci/docker-agent/tree/master/README_inbound-agent.md) image.
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
docker run -i --rm --name agent1 --init -v agent1-workdir:C:/Users/jenkins/Work jenkins/agent:jdk17-windowsservercore-ltsc2019 java -jar C:/ProgramData/Jenkins/agent.jar -workDir C:/Users/jenkins/Work
```

## Configurations

The image has several supported configurations, which can be accessed via the following tags:

* Linux Images:
  * Java 17 (default):
    * `jenkins/agent:latest`: Based on `debian:bookworm-${builddate}`
      * Also tagged as: 
        * `jenkins/agent:jdk17`
        * `jenkins/agent:bookworm-jdk17`
        * `jenkins/agent:latest-bookworm`
        * `jenkins/agent:latest-bookworm-jdk17`
        * `jenkins/agent:latest-jdk17`
    * alpine (Small image based on Alpine Linux, based on `alpine:${version}`):
      * `jenkins/agent:jenkins/agent:alpine` 
      * `jenkins/agent:alpine-jdk17`
      * `jenkins/agent:latest-alpine`
      * `jenkins/agent:latest-alpine-jdk17`
    * rhel-ubi9 (Based on Red Hat Universal Base Image 9)
      * `jenkins/agent:rhel-ubi9`
      * `jenkins/agent:rhel-ubi9-jdk17`
      * `jenkins/agent:latest-rhel-ubi9`
      * `jenkins/agent:latest-rhel-ubi9-jdk17`
  * Java 21:
    * bookworm (Based on `debian:bookworm-${builddate}`):
      * `jenkins/agent:bookworm`
      * `jenkins/agent:bookworm-jdk21`
      * `jenkins/agent:jdk21`
      * `jenkins/agent:latest-bookworm-jdk21`
    * alpine (Small image based on Alpine Linux, based on `alpine:${version}`):
      * `jenkins/agent:alpine` 
      * `jenkins/agent:alpine-jdk21`
      * `jenkins/agent:latest-alpine`
      * `jenkins/agent:latest-alpine-jdk21`
    * rhel-ubi9 (Based on Red Hat Universal Base Image 9)
      * `jenkins/agent:rhel-ubi9-jdk21`
      * `jenkins/agent:latest-rhel-ubi9-jdk21`

* Windows Images:
  * Java 17 (default):
    * Latest Jenkins agent version on Windows Nano Server and Java 17:
      * `jenkins/agent:jdk17-nanoserver-1809`
      * `jenkins/agent:jdk17-nanoserver-ltsc2019`
      * `jenkins/agent:jdk17-nanoserver-ltsc2022`
  * Java 21:
    * Latest Jenkins agent version on Windows Nano Server and Java 21:
      * `jenkins/agent:jdk21-nanoserver-1809`
      * `jenkins/agent:jdk21-nanoserver-ltsc2019`
      * `jenkins/agent:jdk21-nanoserver-ltsc2022`
    * Latest Jenkins agent version on Windows Server Core with Java 21:
      * `jenkins/agent:jdk21-windowsservercore-1809`
      * `jenkins/agent:jdk21-windowsservercore-ltsc2019`
      * `jenkins/agent:jdk21-windowsservercore-ltsc2022`

The file [docker-bake.hcl](https://github.com/jenkinsci/docker-agent/blob/master/docker-bake.hcl) defines all the configuration for Linux images and their associated tags.

There are also versioned tags in DockerHub, and they are recommended for production use.
See the full list at [https://hub.docker.com/r/jenkins/agent/tags](https://hub.docker.com/r/jenkins/agent/tags)

## Timezones

By default, the image is using the `Etc/UTC` timezone.
If you want to use the timezone of your machine, you can mount the `/etc/localtime` file from the host (as per [this comment](https://github.com/moby/moby/issues/12084#issuecomment-89697533)) and the `/etc/timezone` from the host too.

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

## Changelog

See [GitHub releases](https://github.com/jenkinsci/docker-agent/releases) for versions `3.35-1` and above.
There is no changelog for previous versions, see the commit history.

Jenkins remoting changelogs are available at [https://github.com/jenkinsci/remoting/releases](https://github.com/jenkinsci/remoting/releases).

