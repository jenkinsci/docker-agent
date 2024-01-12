ARG DEBIAN_RELEASE=bookworm-20230904
FROM debian:"${DEBIAN_RELEASE}"-slim as jre-build
ARG JAVA_VERSION
ARG TARGETPLATFORM

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

## Example of preview (EA) jdk21 JAVA_VERSION values:
# 21+35 (note: only one number before the "+")
# 21.0.1+12
## Example of preview (EA) release download link:
# https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21%2B35-ea-beta/OpenJDK21U-jdk_x64_linux_hotspot_ea_21-0-35.tar.gz
# https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.1%2B12-ea-beta/OpenJDK21U-jdk_x64_alpine-linux_hotspot_ea_21-0-1-12.tar.gz

# hadolint ignore=DL3008
RUN set -x; apt-get update \
  && apt-get install --no-install-recommends -y \
    ca-certificates \
    jq \
    wget \
  && DASHED_JAVA_VERSION=$(echo "$JAVA_VERSION" | sed -e 's/\./-/g' -e 's/+/-/' -e 's/21-35/21-0-35/') \
  && JAVA_MAJOR_VERSION=$(echo "$JAVA_VERSION" | cut -d'+' -f1 | cut -d'.' -f1) \
  && ENCODED_JAVA_VERSION=$(echo "$JAVA_VERSION" | jq "@uri" -jRr) \
  && CONVERTED_ARCH=$(arch | sed -e 's/x86_64/x64/' -e 's/armv7l/arm/') \
  && wget --quiet https://github.com/adoptium/temurin"${JAVA_MAJOR_VERSION}"-binaries/releases/download/jdk-"${ENCODED_JAVA_VERSION}"-ea-beta/OpenJDK"${JAVA_MAJOR_VERSION}"U-jdk_"${CONVERTED_ARCH}"_linux_hotspot_ea_"${DASHED_JAVA_VERSION}".tar.gz -O /tmp/jdk.tar.gz \
  && tar -xzf /tmp/jdk.tar.gz -C /opt/ \
  && rm -f /tmp/jdk.tar.gz

ENV PATH=/opt/jdk-${JAVA_VERSION}/bin:$PATH

RUN if test "${TARGETPLATFORM}" != 'linux/arm/v7'; then \
      jlink \
        --add-modules ALL-MODULE-PATH \
        --no-man-pages \
        --compress=zip-6 \
        --output /javaruntime; \
    # It is acceptable to have a larger image in arm/v7 (arm 32 bits) environment.
    # Because jlink fails with the error "jmods: Value too large for defined data type" error.
    else  \
      cp -r "/opt/jdk-${JAVA_VERSION}" /javaruntime; \
    fi

## Agent image target
FROM debian:"${DEBIAN_RELEASE}" AS agent

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

RUN groupadd -g "${gid}" "${group}" \
  && useradd -l -c "Jenkins user" -d /home/"${user}" -u "${uid}" -g "${gid}" -m "${user}" || echo "user ${user} already exists."

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
  && rm -rf /tmp/* /var/cache/* /var/lib/apt/lists/*

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
RUN mkdir -p /home/${user}/.jenkins && mkdir -p "${AGENT_WORKDIR}"

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

## Inbound Agent image target
FROM agent AS inbound-agent

ARG user=jenkins

USER root
COPY ../../jenkins-agent /usr/local/bin/jenkins-agent
RUN chmod +x /usr/local/bin/jenkins-agent &&\
    ln -s /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave
USER ${user}

LABEL \
  org.opencontainers.image.vendor="Jenkins project" \
  org.opencontainers.image.title="Official Jenkins Inbound Agent Base Docker image" \
  org.opencontainers.image.description="This is an image for Jenkins agents using TCP or WebSockets to establish inbound connection to the Jenkins controller" \
  org.opencontainers.image.version="${VERSION}" \
  org.opencontainers.image.url="https://www.jenkins.io/" \
  org.opencontainers.image.source="https://github.com/jenkinsci/docker-agent-inbound" \
  org.opencontainers.image.licenses="MIT"

ENTRYPOINT ["/usr/local/bin/jenkins-agent"]
