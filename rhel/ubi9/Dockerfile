ARG UBI9_TAG=9.5-1732804088
FROM registry.access.redhat.com/ubi9/ubi:"${UBI9_TAG}" AS jre-build
SHELL ["/bin/bash", "-e", "-u", "-o", "pipefail", "-c"]

# This Build ARG is populated by Docker
# Ref. https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope
ARG TARGETPLATFORM

COPY adoptium-get-jdk-link.sh /usr/bin/local/adoptium-get-jdk-link.sh
COPY adoptium-install-jdk.sh /usr/bin/local/adoptium-install-jdk.sh

ARG JAVA_VERSION=17.0.12_7

RUN dnf install --disableplugin=subscription-manager --setopt=install_weak_deps=0 --setopt=tsflags=nodocs --allowerasing -y \
    ca-certificates \
    curl \
    jq \
    && dnf clean --disableplugin=subscription-manager all \
    && /usr/bin/local/adoptium-install-jdk.sh

ENV PATH="/opt/jdk-${JAVA_VERSION}/bin:${PATH}"

# Generate smaller java runtime without unneeded files
# for now we include the full module path to maintain compatibility
# while still saving space (approx 200mb from the full distribution)
RUN case "$(jlink --version 2>&1)" in \
      "17."*) set -- "--compress=2" ;; \
      # the compression argument is different for JDK21
      "21."*) set -- "--compress=zip-6" ;; \
      *) echo "ERROR: unmanaged jlink version pattern" && exit 1 ;; \
    esac; \
    jlink \
      --strip-java-debug-attributes \
      "$1" \
      --add-modules ALL-MODULE-PATH \
      --no-man-pages \
      --no-header-files \
      --output /javaruntime

FROM registry.access.redhat.com/ubi9/ubi:"${UBI9_TAG}" AS agent

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

RUN groupadd -g "${gid}" "${group}" \
  && useradd -l -c "Jenkins user" -d /home/"${user}" -u "${uid}" -g "${gid}" -m "${user}" || echo "user ${user} already exists."

ARG AGENT_WORKDIR=/home/"${user}"/agent
ENV TZ=Etc/UTC

RUN dnf install --disableplugin=subscription-manager --setopt=install_weak_deps=0 --setopt=tsflags=nodocs -y \
      ca-certificates \
      fontconfig \
      git \
      git-lfs \
      less \
      patch \
      tzdata \
    && dnf clean --disableplugin=subscription-manager all

ARG VERSION=3261.v9c670a_4748a_9
ADD --chown="${user}":"${group}" "https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${VERSION}/remoting-${VERSION}.jar" /usr/share/jenkins/agent.jar
RUN chmod 0644 /usr/share/jenkins/agent.jar \
    && ln -sf /usr/share/jenkins/agent.jar /usr/share/jenkins/slave.jar

ENV LANG C.UTF-8

ENV JAVA_HOME=/opt/java/openjdk
COPY --from=jre-build /javaruntime "$JAVA_HOME"
ENV PATH="${JAVA_HOME}/bin:${PATH}"

USER "${user}"
ENV AGENT_WORKDIR=${AGENT_WORKDIR}
RUN mkdir -p /home/"${user}"/.jenkins && mkdir -p "${AGENT_WORKDIR}"

VOLUME /home/"${user}"/.jenkins
VOLUME "${AGENT_WORKDIR}"
WORKDIR /home/"${user}"
ENV USER=${user}
LABEL \
  org.opencontainers.image.vendor="Jenkins project" \
  org.opencontainers.image.title="Official Jenkins Agent Base container image for UBI 9" \
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
  org.opencontainers.image.title="Official Jenkins Inbound Agent Base container image for UBI 9" \
  org.opencontainers.image.description="This is an image for Jenkins agents using TCP or WebSockets to establish inbound connection to the Jenkins controller" \
  org.opencontainers.image.version="${VERSION}" \
  org.opencontainers.image.url="https://www.jenkins.io/" \
  org.opencontainers.image.source="https://github.com/jenkinsci/docker-agent" \
  org.opencontainers.image.licenses="MIT"

ENTRYPOINT ["/usr/local/bin/jenkins-agent"]
