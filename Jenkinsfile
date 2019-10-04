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
                        timeout(time: 30, unit: 'MINUTES')
                    }
                    environment {
                        DOCKERHUB_ORGANISATION = 'jenkins4eval'
                    }
                    steps {
                        script {
                            // we can't use dockerhub builds for windows
                            // so we publish here
                            if (infra.isTrusted()) {
                                env.DOCKERHUB_ORGANISATION = 'jenkins'
                            }

                            infra.withDockerCredentials {
                                powershell '& ./make.ps1 publish'
                            }
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
                                sh './build.sh'
                            }
                        }
                    }
                }
            }
        }
    }

}

// vim: ft=groovy
