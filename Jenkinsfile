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
                        label "windock"
                    }
                    options {
                        timeout(time: 60, unit: 'MINUTES')
                    }
                    environment {
                        DOCKERHUB_ORGANISATION = "${infra.isTrusted() ? 'jenkins' : 'jenkins4eval'}"
                    }
                    steps {
                        script {
                            powershell '& ./make.ps1 test'

                            def branchName = "${env.BRANCH_NAME}"
                            if (branchName ==~ 'master') {
                                // we can't use dockerhub builds for windows
                                // so we publish here
                                infra.withDockerCredentials {
                                    powershell '& ./make.ps1 publish'
                                }
                            }

                            if(env.TAG_NAME != null) {
                                def tagItems = env.TAG_NAME.split('-')
                                if(tagItems.length == 2) {
                                    def remotingVersion = tagItems[0]
                                    def buildNumber = tagItems[1]
                                    // we need to build and publish the tag version
                                    infra.withDockerCredentials {
                                        powershell "& ./make.ps1 -PushVersions -RemotingVersion $remotingVersion -BuildNumber $buildNumber publish"
                                    }
                                }
                            }

                            // cleanup any docker images
                            powershell '& docker system prune --force --all'
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
                    steps {
                        script {
                            if(!infra.isTrusted()) {
                                sh './build.sh ; docker system prune --force --all'
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
