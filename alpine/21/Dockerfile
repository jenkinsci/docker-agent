ARG ALPINE_TAG=3.18.3
FROM alpine:"${ALPINE_TAG}" AS jre-build
ARG JAVA_VERSION
ARG TARGETPLATFORM

# hadolint ignore=DL4006
RUN apk add --no-cache jq wget \
  && BUILD_NUMBER=$(echo $JAVA_VERSION | cut -d'+' -f2) \
  && JAVA_MAJOR_VERSION=$(echo $JAVA_VERSION | cut -d'+' -f1) \
  && JAVA_VERSION_ENCODED=$(echo $JAVA_VERSION | jq '@uri' -jRr) \
  && CONVERTED_ARCH=$(arch | sed 's/x86_64/x64/') \
  && wget --quiet https://github.com/adoptium/temurin"${JAVA_MAJOR_VERSION}"-binaries/releases/download/jdk-"${JAVA_VERSION_ENCODED}"-ea-beta/OpenJDK"${JAVA_MAJOR_VERSION}"U-jdk_"${CONVERTED_ARCH}"_alpine-linux_hotspot_ea_"${JAVA_MAJOR_VERSION}"-0-"${BUILD_NUMBER}".tar.gz -O /tmp/jdk.tar.gz \
  && tar -xzf /tmp/jdk.tar.gz -C /opt/ \
  && rm -f /tmp/jdk.tar.gz

ENV PATH=/opt/jdk-${JAVA_VERSION}/bin:$PATH

# Generate smaller java runtime without unneeded files
# for now we include the full module path to maintain compatibility
# while still saving space (approx 200mb from the full distribution)
RUN if [ "$TARGETPLATFORM" != 'linux/arm/v7' ]; then \
    case "$(jlink --version 2>&1)" in \
      # jlink version 11 has less features than JDK17+
      "11."*) strip_java_debug_flags="--strip-debug" ;; \
      *) strip_java_debug_flags="--strip-java-debug-attributes" ;; \
    esac; \
    jlink \
      --add-modules ALL-MODULE-PATH \
      "$strip_java_debug_flags" \
      --no-man-pages \
      --no-header-files \
      --compress=zip-6 \
      --output /javaruntime; \
  else \
    cp -r /opt/jdk-${JAVA_VERSION} /javaruntime; \
  fi

FROM alpine:"${ALPINE_TAG}" AS build

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

RUN addgroup -g "${gid}" "${group}" \
  && adduser -h /home/"${user}" -u "${uid}" -G "${group}" -D "${user}"

ARG AGENT_WORKDIR=/home/"${user}"/agent

ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'
ENV TZ=Etc/UTC

## Always use the latest Alpine packages: no need for versions
# hadolint ignore=DL3018
RUN apk add --no-cache \
      curl \
      bash \
      git \
      git-lfs \
      musl-locales \
      openssh-client \
      openssl \
      procps \
      tzdata \
      tzdata-utils \
    && rm -rf /tmp/*.apk /tmp/gcc /tmp/gcc-libs.tar* /tmp/libz /tmp/libz.tar.xz /var/cache/apk/*

ARG VERSION=3148.v532a_7e715ee3
ADD --chown="${user}":"${group}" "https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${VERSION}/remoting-${VERSION}.jar" /usr/share/jenkins/agent.jar
RUN chmod 0644 /usr/share/jenkins/agent.jar \
  && ln -sf /usr/share/jenkins/agent.jar /usr/share/jenkins/slave.jar


ENV JAVA_HOME=/opt/java/openjdk
COPY --from=jre-build /javaruntime "$JAVA_HOME"
ENV PATH="${JAVA_HOME}/bin:${PATH}"

USER "${user}"
ENV AGENT_WORKDIR="${AGENT_WORKDIR}"
RUN mkdir /home/"${user}"/.jenkins && mkdir -p "${AGENT_WORKDIR}"

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
