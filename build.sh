#!/bin/bash

set -euxo pipefail

for dockerfile in Dockerfile*
do
    # skip windows build
    if [[ $dockerfile == *windows* ]]; then
        continue
    fi    
    dockertag=$( echo "$dockerfile" | cut -d ' ' -f 2 )
    if [[ "$dockertag" = "$dockerfile" ]]; then
        dockertag='latest'
    fi
    echo "Building $dockerfile => tag=$dockertag"
    docker build -f $dockerfile -t jenkins/slave:$dockertag .
    docker build -f $dockerfile -t jenkins/agent:$dockertag .
done

echo "Build finished successfully"
