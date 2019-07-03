foreach($dockerfile in (gci Dockerfile-windows*)) {
    echo "Building $dockerfile => tag=latest"
    docker build -f $dockerfile -t jenkins/agent-windows:latest .
}

Write-Host "Build finished successfully"
