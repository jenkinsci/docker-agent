# escape=`

# The MIT License
#
#  Copyright (c) 2020, Alex Earl and other Jenkins Contributors
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.

# If you pass in a POWERSHELL_VERSION, make sure it ends with a hyphen, leaving it empty will
# use the 'latest'
ARG POWERSHELL_VERSION=
FROM mcr.microsoft.com/powershell:${POWERSHELL_VERSION}nanoserver-1809

ARG JAVA_VERSION=11.0.6+10
ARG JAVA_SHA256=6fb8b6c254ec0e1091acd421ac79c1bb07b295de0b679c0595fd284caf7734e5
ARG JAVA_HOME=C:\jdk-${JAVA_VERSION}

SHELL ["pwsh.exe", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

USER ContainerAdministrator

RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; `
    $javaRoot = 'OpenJDK11U-jdk_x64_windows_hotspot_{0}' -f $env:JAVA_VERSION.Replace('+', '_') ; `
    $url = 'https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-{0}/{1}.zip' -f [System.Uri]::EscapeDataString($env:JAVA_VERSION), $javaRoot ; `
    Write-Host "Retrieving $url..." ; `
    Invoke-WebRequest $url -OutFile 'openjdk.zip' -UseBasicParsing ; `
    if ((Get-FileHash openjdk.zip -Algorithm sha256).Hash -ne $env:JAVA_SHA256) { Write-Error 'Java SHA256 mismatch' ; exit 1} ; `
    Expand-Archive openjdk.zip -DestinationPath C:/ ; `
    Remove-Item -Path openjdk.zip

ARG VERSION=4.3

# metadata labels
LABEL `
    org.label-schema.schema-version="1.0" `
    org.label-schema.vendor="Jenkins project" `
    org.label-schema.name="Official Jenkins Docker image" `
    org.label-schema.description="This is a base image, which provides the Jenkins agent executable (agent.jar)" `
    org.label-schema.version="${VERSION}" `
    org.label-schema.url="https://jenkins.io/" `
    org.label-schema.vcs-url="https://github.com/jenkinsci/docker-agent" `
    org.label-schema.license="MIT"

ARG GIT_VERSION=2.26.0
ARG GIT_PATCH_VERSION=1
RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; `
    $url = $('https://github.com/git-for-windows/git/releases/download/v{0}.windows.{1}/MinGit-{0}-busybox-64-bit.zip' -f $env:GIT_VERSION, $env:GIT_PATCH_VERSION) ; `
    Write-Host "Retrieving $url..." ; `
    Invoke-WebRequest $url -OutFile 'mingit.zip' -UseBasicParsing ; `
    Expand-Archive mingit.zip -DestinationPath c:\mingit ; `
    Remove-Item mingit.zip -Force

ARG GIT_LFS_VERSION=2.10.0
RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; `
    $url = $('https://github.com/git-lfs/git-lfs/releases/download/v{0}/git-lfs-windows-amd64-v{0}.zip' -f $env:GIT_LFS_VERSION) ; `
    Write-Host "Retrieving $url..." ; `
    Invoke-WebRequest $url -OutFile 'GitLfs.zip' -UseBasicParsing ; `
    Expand-Archive GitLfs.zip -DestinationPath c:\mingit\mingw64\bin ; `
    Remove-Item GitLfs.zip -Force

ENV ProgramFiles="C:\Program Files"
ENV WindowsPATH="C:\Windows\system32;C:\Windows"
ENV PATH="${WindowsPATH};${ProgramFiles}\PowerShell;${JAVA_HOME}\bin;C:\mingit\cmd"

ARG user=jenkins

ARG AGENT_FILENAME=agent.jar
ARG AGENT_HASH_FILENAME=$AGENT_FILENAME.sha1

RUN net user "$env:user" /add /expire:never /passwordreq:no ; `
    net localgroup Administrators /add $env:user ; `
    setx /M PATH '%PATH%;%JAVA_HOME%\bin' ; `
    New-Item -ItemType Directory -Path C:/ProgramData/Jenkins | Out-Null

ARG AGENT_ROOT=C:/Users/$user
ARG AGENT_WORKDIR=${AGENT_ROOT}/Work

ENV AGENT_WORKDIR=${AGENT_WORKDIR}

# Get the Agent from the Jenkins Artifacts Repository
RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; `
    Invoke-WebRequest $('https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/{0}/remoting-{0}.jar' -f $env:VERSION) -OutFile $(Join-Path C:/ProgramData/Jenkins $env:AGENT_FILENAME) -UseBasicParsing ; `
    Invoke-WebRequest $('https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/{0}/remoting-{0}.jar.sha1' -f $env:VERSION) -OutFile (Join-Path C:/ProgramData/Jenkins $env:AGENT_HASH_FILENAME) -UseBasicParsing ; `
    if ((Get-FileHash (Join-Path C:/ProgramData/Jenkins $env:AGENT_FILENAME) -Algorithm SHA1).Hash -ne (Get-Content (Join-Path C:/ProgramData/Jenkins $env:AGENT_HASH_FILENAME))) {exit 1} ; `
    Remove-Item -Force (Join-Path C:/ProgramData/Jenkins $env:AGENT_HASH_FILENAME)

USER $user

RUN New-Item -Type Directory $('{0}/.jenkins' -f $env:AGENT_ROOT) | Out-Null ; `
    New-Item -Type Directory $env:AGENT_WORKDIR | Out-Null

VOLUME ${AGENT_ROOT}/.jenkins
VOLUME ${AGENT_WORKDIR}
WORKDIR ${AGENT_ROOT}
