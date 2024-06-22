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

ARG WINDOWS_VERSION_TAG=ltsc2019
ARG TOOLS_WINDOWS_VERSION # Empty (only used on nanoserver)
# TODO: workaround, to be removed when https://github.com/microsoft/Windows-Containers/issues/493 is resolved
ARG WINDOWS_VERSION_DIGEST # Empty by default
FROM mcr.microsoft.com/windows/servercore:"${WINDOWS_VERSION_TAG}${WINDOWS_VERSION_DIGEST}" AS jdk-core

# $ProgressPreference: https://github.com/PowerShell/PowerShell/issues/2138#issuecomment-251261324
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG JAVA_VERSION=17.0.10+7
RUN New-Item -ItemType Directory -Path C:\temp | Out-Null ; `
    $javaMajorVersion = $env:JAVA_VERSION.substring(0,2) ; `
    $msiUrl = 'https://api.adoptium.net/v3/installer/version/jdk-{0}/windows/x64/jdk/hotspot/normal/eclipse?project=jdk' -f $env:JAVA_VERSION.Replace('+', '%2B') ; `
    Invoke-WebRequest $msiUrl -OutFile 'C:\temp\jdk.msi' ; `
    $proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList '/i', 'C:\temp\jdk.msi', '/L*V', 'C:\temp\OpenJDK.log', '/quiet', 'ADDLOCAL=FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome',  "INSTALLDIR=C:\openjdk-${javaMajorVersion}" -Wait -Passthru ; `
    $proc.WaitForExit() ; `
    Remove-Item -Path C:\temp -Recurse | Out-Null

## Agent image target
FROM mcr.microsoft.com/windows/servercore:"${WINDOWS_VERSION_TAG}${WINDOWS_VERSION_DIGEST}" AS agent

ARG JAVA_HOME="C:\openjdk-17"
ENV JAVA_HOME=${JAVA_HOME}

COPY --from=jdk-core $JAVA_HOME $JAVA_HOME

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG GIT_VERSION=2.45.2
ARG GIT_PATCH_VERSION=1
RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; `
    # The patch "windows.1" always have a different URL than the subsequent patch (ZIP filename is different)
    if($env:GIT_PATCH_VERSION -eq 1) { $url = $('https://github.com/git-for-windows/git/releases/download/v{0}.windows.{1}/MinGit-{0}-64-bit.zip' -f $env:GIT_VERSION, $env:GIT_PATCH_VERSION); } `
    else {$url = $('https://github.com/git-for-windows/git/releases/download/v{0}.windows.{1}/MinGit-{0}.{1}-64-bit.zip' -f $env:GIT_VERSION, $env:GIT_PATCH_VERSION)} ; `
    Write-Host "Retrieving $url..." ; `
    Invoke-WebRequest $url -OutFile 'mingit.zip' -UseBasicParsing ; `
    Expand-Archive mingit.zip -DestinationPath c:\mingit ; `
    Remove-Item mingit.zip -Force

# Add git and java in PATH
RUN $CurrentPath = (Get-Itemproperty -path 'hklm:\system\currentcontrolset\control\session manager\environment' -Name Path).Path ; `
    $NewPath = $CurrentPath + $(';{0}\bin;C:\mingit\cmd' -f $env:JAVA_HOME) ; `
    Set-ItemProperty -path 'hklm:\system\currentcontrolset\control\session manager\environment' -Name Path -Value $NewPath

ARG GIT_LFS_VERSION=3.5.1
RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; `
    $url = $('https://github.com/git-lfs/git-lfs/releases/download/v{0}/git-lfs-windows-amd64-v{0}.zip' -f $env:GIT_LFS_VERSION) ; `
    Write-Host "Retrieving $url..." ; `
    Invoke-WebRequest $url -OutFile 'GitLfs.zip' -UseBasicParsing ; `
    Expand-Archive GitLfs.zip -DestinationPath c:\mingit\mingw64\bin ; `
    $gitLfsFolder = 'c:\mingit\mingw64\bin\git-lfs-{0}' -f $env:GIT_LFS_VERSION ; `
    Move-Item -Path "${gitLfsFolder}\git-lfs.exe" -Destination c:\mingit\mingw64\bin\ ; `
    Remove-Item -Path $gitLfsFolder -Recurse -Force ; `
    Remove-Item GitLfs.zip -Force ; `
    & c:\mingit\mingw64\bin\git-lfs.exe install

ARG user=jenkins

ARG AGENT_FILENAME=agent.jar
ARG AGENT_HASH_FILENAME=$AGENT_FILENAME.sha1

RUN net accounts /maxpwage:unlimited ; `
    net user "$env:user" /add /expire:never /passwordreq:no ; `
    net localgroup Administrators /add $env:user ; `
    Set-LocalUser -Name $env:user -PasswordNeverExpires 1; `
    New-Item -ItemType Directory -Path C:/ProgramData/Jenkins | Out-Null

ARG AGENT_ROOT=C:/Users/$user
ARG AGENT_WORKDIR=${AGENT_ROOT}/Work

ENV AGENT_WORKDIR=${AGENT_WORKDIR}

# Get the Agent from the Jenkins Artifacts Repository
ARG VERSION=3256.v88a_f6e922152
RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; `
    Invoke-WebRequest $('https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/{0}/remoting-{0}.jar' -f $env:VERSION) -OutFile $(Join-Path C:/ProgramData/Jenkins $env:AGENT_FILENAME) -UseBasicParsing ; `
    Invoke-WebRequest $('https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/{0}/remoting-{0}.jar.sha1' -f $env:VERSION) -OutFile (Join-Path C:/ProgramData/Jenkins $env:AGENT_HASH_FILENAME) -UseBasicParsing ; `
    if ((Get-FileHash (Join-Path C:/ProgramData/Jenkins $env:AGENT_FILENAME) -Algorithm SHA1).Hash -ne (Get-Content (Join-Path C:/ProgramData/Jenkins $env:AGENT_HASH_FILENAME))) {exit 1} ; `
    Remove-Item -Force (Join-Path C:/ProgramData/Jenkins $env:AGENT_HASH_FILENAME)

USER $user

RUN New-Item -Type Directory $('{0}/.jenkins' -f $env:AGENT_ROOT) | Out-Null ; `
    New-Item -Type Directory $env:AGENT_WORKDIR | Out-Null

RUN git config --global core.longpaths true

VOLUME "${AGENT_ROOT}"/.jenkins
VOLUME "${AGENT_WORKDIR}"
WORKDIR "${AGENT_ROOT}"
ENV user=${user}
LABEL `
    org.opencontainers.image.vendor="Jenkins project" `
    org.opencontainers.image.title="Official Jenkins Agent Base Docker image" `
    org.opencontainers.image.description="This is a base image, which provides the Jenkins agent executable (agent.jar)" `
    org.opencontainers.image.version="${VERSION}" `
    org.opencontainers.image.url="https://www.jenkins.io/" `
    org.opencontainers.image.source="https://github.com/jenkinsci/docker-agent" `
    org.opencontainers.image.licenses="MIT"

## Inbound Agent image target
FROM agent AS inbound-agent

COPY jenkins-agent.ps1 C:/ProgramData/Jenkins

LABEL `
    org.opencontainers.image.vendor="Jenkins project" `
    org.opencontainers.image.title="Official Jenkins Inbound Agent Base Docker image" `
    org.opencontainers.image.description="This is an image for Jenkins agents using TCP or WebSockets to establish inbound connection to the Jenkins controller" `
    org.opencontainers.image.version="${VERSION}" `
    org.opencontainers.image.url="https://www.jenkins.io/" `
    org.opencontainers.image.source="https://github.com/jenkinsci/docker-agent" `
    org.opencontainers.image.licenses="MIT"

ENTRYPOINT ["powershell.exe", "-f", "C:/ProgramData/Jenkins/jenkins-agent.ps1"]
