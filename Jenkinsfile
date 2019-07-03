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
        parallel {
            stage('Build Linux Images') {
                steps {
                    sh './build.sh'
                }
            }
            stage('Build Windows Images') {
                agent { label 'docker-windows' }
                steps {
                    powershell './build.ps1'
                }
            }
        }
    }
}

// vim: ft=groovy
