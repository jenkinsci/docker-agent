pipeline {
    agent none

    options {        
        buildDiscarder(logRotator(daysToKeepStr: '10'))
        timestamps()
    }

    triggers {
        pollSCM('H * * * *')
    }

    stages {
        stage('Build') {
            parallel {
                stage('Windows') {
                    agent {
                        label "docker-windows"
                    }
                    options {
                        timeout(time: 60, unit: 'MINUTES')
                    }
                    environment {
                        DOCKERHUB_ORGANISATION = "${infra.isTrusted() ? 'jenkins' : 'jenkins4eval'}"
                    }
                    steps {
                        powershell '& ./build.ps1 test'
                        script {
                            def branchName = "${env.BRANCH_NAME}"
                            if (branchName ==~ 'master') {
                                // publish the images to Dockerhub
                                infra.withDockerCredentials {
                                    powershell '& ./build.ps1 publish'
                                }
                            }

                            if(env.TAG_NAME != null) {
                                def tagItems = env.TAG_NAME.split('-')
                                if(tagItems.length == 2) {
                                    def remotingVersion = tagItems[0]
                                    def buildNumber = tagItems[1]
                                    // we need to build and publish the tag version
                                    infra.withDockerCredentials {
                                        powershell "& ./build.ps1 -PushVersions -RemotingVersion $remotingVersion -BuildNumber $buildNumber -DisableEnvProps publish"
                                    }
                                }
                            }
                        }
                    }
                    post {
                        always {
                            junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/**/junit-results.xml')
                        }
                    }
                }
                stage('Linux') {
                    agent {
                        label "docker&&linux"
                    }
                    options {
                        timeout(time: 30, unit: 'MINUTES')
                    }
                    environment {
                        DOCKERHUB_ORGANISATION = "${infra.isTrusted() ? 'jenkins' : 'jenkins4eval'}"
                    }
                    steps {
                        sh './build.sh'
                        sh './build.sh test'
                        script {
                            def branchName = "${env.BRANCH_NAME}"
                            if (branchName ==~ 'master') {
                                // publish the images to Dockerhub
                                infra.withDockerCredentials {
                                    sh '''
                                    docker buildx create --use
                                    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
                                    ./build.sh publish
                                    '''
                                }
                            } else if (env.TAG_NAME == null) {
                                infra.withDockerCredentials {
                                    sh '''
                                        docker buildx create --use
                                        docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
                                        docker buildx bake --file docker-bake.hcl linux
                                    '''
                                }
                            }

                            if(env.TAG_NAME != null) {
                                def tagItems = env.TAG_NAME.split('-')
                                if(tagItems.length == 2) {
                                    def remotingVersion = tagItems[0]
                                    def buildNumber = tagItems[1]
                                    // we need to build and publish the tag version
                                    infra.withDockerCredentials {
                                        sh """
                                        docker buildx create --use
                                        docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
                                        ./build.sh -r $remotingVersion -b $buildNumber -d publish
                                        """
                                    }
                                }
                            }
                        }
                    }
                    post {
                        always {
                            junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/*.xml')
                        }
                    }
                }
            }
        }
    }

}

// vim: ft=groovy
