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
        stage('Prepare Workspace') {
            steps {
                sh './build.sh'
            }
        }
    }

}

// vim: ft=groovy
