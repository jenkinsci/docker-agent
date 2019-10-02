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

        // stage('Prepare') {
        //     String linuxDockerfiles = sh
        // }
        linuxDockerfiles = ["Dockerfile", "Dockerfile-jdk11", "Dockerfile-alpine"]

        def allStages = [:]
        for(int i=0; i<linuxDockerfiles.length; i++){
            allStages[linuxDockerfiles[i]] = buildLinuxDockerfile(linuxDockerfiles[i])
        }
        stage('Build') {
            parallel allStages
            // parallel {
            //     stage('Windows') {
            //         agent {
            //             label "windock"
            //         }
            //         steps {
            //             powershell "& ./build.ps1"
            //         }
            //     }
            //     stage('Linux') {
            //         agent {
            //             label "docker"
            //         }
            //         steps {
            //             sh "./build.sh"
            //         }
            //     }
            // }
        }
    }

}

def buildLinuxDockerfile(dockerfile) {
    return {
        stage("Build-${dockerfile}") {
            agent {
                label "docker"
            }
            environment {
                DOCKERFILE = dockerfile
            }
            steps {
                sh '''
                    dockertag=$( echo "${DOCKERFILE}" | cut -d ' ' -f 2 )
                    if [[ "$dockertag" = "${DOCKERFILE}" ]]; then
                        dockertag='latest'
                    fi
                    echo "Building ${DOCKERFILE} => tag=$dockertag"

                    docker build -f ${DOCKERFILE} -t jenkins/slave:$dockertag .
                    docker run --rm --entrypoint jarsigner jenkins/slave:$dockertag \
                        -verify /usr/share/jenkins/agent.jar

                    docker build -f ${DOCKERFILE} -t jenkins/agent:$dockertag .
                    docker run --rm --entrypoint jarsigner jenkins/agent:$dockertag \
                        -verify /usr/share/jenkins/agent.jar
                '''
            }
        }
    }
}


// vim: ft=groovy
