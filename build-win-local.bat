@rem Utility script to build the windows agent locally

@setlocal
@set DOCKERHUB_ORGANISATION=794835664978.dkr.ecr.eu-west-1.amazonaws.com
@set DOCKERHUB_REPO=jenkins/inbound-agent
@set WINDOWS_FLAVOR=windowsservercore
@set WINDOWS_VERSION_TAG=ltsc2022
@set BUILD_NUMBER=0

docker-compose --env-file=env.props --file=build-windows.yaml build --pull jdk17
