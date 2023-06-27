pipeline {
    agent none

    options {
        buildDiscarder(logRotator(daysToKeepStr: '10'))
        timestamps()
    }

    stages {
        stage('docker-agent') {
            failFast true
            matrix {
                axes { 
                    axis { 
                        name 'OS_FAMILY'
                        values 'linux', 'windows'
                    }
                    axis {
                        name 'WINDOWS_VERSION'
                        values 'none', '2019'
                    }
                }
                excludes {
                    exclude {
                        axis {
                            name 'OS_FAMILY'
                            values 'linux'
                        }
                        axis {
                            name 'WINDOWS_VERSION'
                            notValues 'none'
                        }
                    }
                    exclude {
                        axis {
                            name 'OS_FAMILY'
                            values 'windows'
                        }
                        axis {
                            name 'WINDOWS_VERSION'
                            values 'none'
                        }
                    }
                }
                stages {
                    stage('Main') {
                        agent {
                            label "${env.OS_FAMILY == 'linux' ? 'docker && linux' : (env.WINDOWS_VERSION != '2019' ? "windows-$WINDOWS_VERSION" : 'docker-windows')}"
                        }
                        options {
                            timeout(time: "${env.OS_FAMILY == 'linux' ? 30 : 60}", unit: 'MINUTES')
                        }
                        environment {
                            DOCKERHUB_ORGANISATION = "${infra.isTrusted() ? 'jenkins' : 'jenkins4eval'}"
                            BUILD_FILE = "build-windows-${env.WINDOWS_VERSION}.yaml"
                            WINDOWS_VERSION_TAG = "${env.WINDOWS_VERSION != '2019' ? "windows-$WINDOWS_VERSION" : 'docker-windows'}"
                        }
                        stages {
                            stage('Prepare Docker') {
                                when {
                                    environment name: 'OS_FAMILY', value: 'linux'
                                }
                                steps {
                                    sh '''
                                    docker buildx create --use
                                    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
                                    '''
                                }
                            }
                            stage('Build and Test') {
                                // This stage is the "CI" and should be run on all code changes triggered by a code change
                                when {
                                    not { buildingTag() }
                                }
                                steps {
                                    script {
                                        if(isUnix()) {
                                            sh './build.sh'
                                            sh './build.sh test'
                                            // If the tests are passing for Linux AMD64, then we can build all the CPU architectures
                                            sh 'docker buildx bake --file docker-bake.hcl linux'
                                        } else {
                                            powershell "& ./build.ps1 -BuildFile ${env.BUILD_FILE} test"
                                        }
                                    }
                                }
                                post {
                                    always {
                                        junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/**/junit-results.xml')
                                    }
                                }
                            }
                            stage('Deploy to DockerHub') {
                                // This stage is the "CD" and should only be run when a tag triggered the build
                                when {
                                    buildingTag()
                                }
                                steps {
                                    script {
                                        if(env.TAG_NAME != null) {
                                            def tagItems = env.TAG_NAME.split('-')
                                            if(tagItems.length == 2) {
                                                def remotingVersion = tagItems[0]
                                                def buildNumber = tagItems[1]
                                                // This function is defined in the jenkins-infra/pipeline-library
                                                infra.withDockerCredentials {
                                                    if (isUnix()) {
                                                        sh """
                                                        docker buildx create --use
                                                        docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
                                                        ./build.sh -r ${remotingVersion} -b ${buildNumber} -d publish
                                                        """
                                                    } else {
                                                        powershell "& ./build.ps1 -PushVersions -RemotingVersion $remotingVersion -BuildNumber $buildNumber -DisableEnvProps publish"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// vim: ft=groovy
