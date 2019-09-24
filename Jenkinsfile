pipeline {
    agent { label 'docker' }

    options {
        timeout(time: 30, unit: 'MINUTES')
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
                    steps {
                        powershell "& ./build.ps1"
                    }
                }
                stage('Linux') {
                    agent {
                        label "docker"
                    }
                    steps {
                        sh "./build.sh"
                    }
                }
            }
        }
    }

}

// vim: ft=groovy
