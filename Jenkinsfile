def agentSelector(String imageType) {
    // Linux agent
    if (imageType == 'linux') {
        // Need Docker and a LOT of memory for faster builds (due to multi archs) or fallback to linux (trusted.ci)
        return 'docker-highmem || linux'
    }
    // Windows Server Core 2022 agent
    if (imageType.contains('2022')) {
        return 'windows-2022'
    }
    // Windows Server Core 2019 agent (for nanoserver 1809 & ltsc2019 and for windowservercore ltsc2019)
    return 'windows-2019'
}

pipeline {
    agent none

    options {
        buildDiscarder(logRotator(daysToKeepStr: '10'))
    }

    stages {
        stage('Pipeline') {
            matrix {
                axes {
                    axis {
                        name 'IMAGE_TYPE'
                        values 'linux', 'nanoserver-1809', 'nanoserver-ltsc2019', 'nanoserver-ltsc2022', 'windowsservercore-1809', 'windowsservercore-ltsc2019', 'windowsservercore-ltsc2022'
                    }
                }
                stages {
                    stage('Main') {
                        agent {
                            label agentSelector(env.IMAGE_TYPE)
                        }
                        options {
                            timeout(time: 60, unit: 'MINUTES')
                        }
                        environment {
                            REGISTRY_ORG = "${infra.isTrusted() ? 'jenkins' : 'jenkins4eval'}"
                        }
                        stages {
                            stage('Prepare Docker') {
                                when {
                                    environment name: 'IMAGE_TYPE', value: 'linux'
                                }
                                steps {
                                    sh 'make docker-init'
                                }
                            }
                            stage('Build and Test') {
                                // This stage is the "CI" and should be run on all code changes triggered by a code change
                                when {
                                    not { buildingTag() }
                                }
                                steps {
                                    script {
                                        if (isUnix()) {
                                            sh './build.sh'
                                            sh './build.sh test'
                                            // If the tests are passing for Linux AMD64, then we can build all the CPU architectures
                                            sh 'make every-build'
                                        } else {
                                            powershell '& ./build.ps1 test'
                                        }
                                    }
                                }
                                post {
                                    always {
                                        archiveArtifacts artifacts: 'build-windows_*.yaml', allowEmptyArchive: true
                                        junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/**/junit-results*.xml')
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
                                        def tagItems = env.TAG_NAME.split('-')
                                        if(tagItems.length == 2) {
                                            withEnv([
                                                "ON_TAG=true",
                                                "REMOTING_VERSION=${tagItems[0]}",
                                                "BUILD_NUMBER=${tagItems[1]}",
                                            ]) {
                                                // This function is defined in the jenkins-infra/pipeline-library
                                                infra.withDockerCredentials {
                                                    if (isUnix()) {
                                                        sh 'make publish'
                                                    } else {
                                                        powershell '& ./build.ps1 publish'
                                                    }
                                                }
                                            }
                                        } else {
                                            error("The deployment to Docker Hub failed because the tag doesn't contain any '-'.")
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
