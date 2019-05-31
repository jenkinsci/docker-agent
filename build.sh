#!/bin/bash

set -euxo pipefail

for dockerfile in Dockerfile*
do
    dockertag=$( echo "$dockerfile" | cut -d ' ' -f 2 )
    if [[ "$dockertag" = "$dockerfile" ]]; then
        dockertag='latest'
    fi
    echo "Building $dockerfile => tag=$dockertag"
    docker build -f $dockerfile -t jenkins/slave:$dockertag .
    docker build -f $dockerfile -t jenkins/agent:$dockertag .
done

echo "Build finished successfully"
