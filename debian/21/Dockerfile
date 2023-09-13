ARG DEBIAN_RELEASE=bookworm-20230904
FROM debian:"${DEBIAN_RELEASE}"-slim as jre-build
ARG JAVA_VERSION
ARG TARGETPLATFORM

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -x; apt-get update \
  && apt-get install --no-install-recommends -y \
    ca-certificates \
    jq \
    wget \
  && BUILD_NUMBER=$(echo $JAVA_VERSION | cut -d'+' -f2) \
  && JAVA_MAJOR_VERSION=$(echo $JAVA_VERSION | cut -d'+' -f1) \
  && JAVA_VERSION_ENCODED=$(echo "$JAVA_VERSION" | jq "@uri" -jRr) \
  && CONVERTED_ARCH=$(arch | sed 's/x86_64/x64/') \
  && wget --quiet https://github.com/adoptium/temurin"${JAVA_MAJOR_VERSION}"-binaries/releases/download/jdk-"${JAVA_VERSION_ENCODED}"-ea-beta/OpenJDK"${JAVA_MAJOR_VERSION}"U-jdk_"${CONVERTED_ARCH}"_linux_hotspot_ea_"${JAVA_MAJOR_VERSION}"-0-"${BUILD_NUMBER}".tar.gz -O /tmp/jdk.tar.gz \
  && tar -xzf /tmp/jdk.tar.gz -C /opt/ \
  && rm -f /tmp/jdk.tar.gz

ENV PATH=/opt/jdk-${JAVA_VERSION}/bin:$PATH

RUN jlink \
  --add-modules ALL-MODULE-PATH \
  --no-man-pages \
  --compress=zip-6 \
  --output /javaruntime


FROM debian:"${DEBIAN_RELEASE}" AS build

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

RUN groupadd -g "${gid}" "${group}" \
  && useradd -l -c "Jenkins user" -d /home/"${user}" -u "${uid}" -g "${gid}" -m "${user}"

ARG AGENT_WORKDIR=/home/"${user}"/agent
ENV TZ=Etc/UTC

## Always use the latest Debian packages: no need for versions
# hadolint ignore=DL3008
RUN apt-get update \
  && apt-get --yes --no-install-recommends install \
    ca-certificates \
    curl \
    fontconfig \
    git \
    git-lfs \
    less \
    netbase \
    openssh-client \
    patch \
    tzdata \
  && apt-get clean \
  && rm -rf /tmp/* /var/cache/* /usr/share/doc/* /usr/share/man/* /var/lib/apt/lists/*

ARG VERSION=3148.v532a_7e715ee3
ADD --chown="${user}":"${group}" "https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${VERSION}/remoting-${VERSION}.jar" /usr/share/jenkins/agent.jar
RUN chmod 0644 /usr/share/jenkins/agent.jar \
  && ln -sf /usr/share/jenkins/agent.jar /usr/share/jenkins/slave.jar

ENV LANG C.UTF-8

ENV JAVA_HOME=/opt/java/openjdk
COPY --from=jre-build /javaruntime "$JAVA_HOME"
ENV PATH="${JAVA_HOME}/bin:${PATH}"

USER "${user}"
ENV AGENT_WORKDIR=${AGENT_WORKDIR}
RUN mkdir /home/${user}/.jenkins && mkdir -p "${AGENT_WORKDIR}"

VOLUME /home/"${user}"/.jenkins
VOLUME "${AGENT_WORKDIR}"
WORKDIR /home/"${user}"
ENV user=${user}
LABEL \
  org.opencontainers.image.vendor="Jenkins project" \
  org.opencontainers.image.title="Official Jenkins Agent Base Docker image" \
  org.opencontainers.image.description="This is a base image, which provides the Jenkins agent executable (agent.jar)" \
  org.opencontainers.image.version="${VERSION}" \
  org.opencontainers.image.url="https://www.jenkins.io/" \
  org.opencontainers.image.source="https://github.com/jenkinsci/docker-agent" \
  org.opencontainers.image.licenses="MIT"
