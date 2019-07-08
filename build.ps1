[CmdletBinding()]
Param(
    [String] $Tag = 'latest',
    [String] $AdditionalArgs = '',
    [String] $Build = ''
)

$builds = @{
    '' = @{ 'Dockerfile' = 'Dockerfile-windows' ; 'BuildArgs' = '' };
    'jdk11' = @{ 'Dockerfile' = 'Dockerfile-windows' ; 'BuildArgs' = '--build-arg `"JAVA_VERSION=11.0.3-1`" --build-arg `"JAVA_BASE_VERSION=11`" --build-arg "JAVA_ZIP_VERSION=11.0.3.7-1" --build-arg "JAVA_SHA256=b13703a7ee5ff3e14881b7d3488fa93942d1858ca3cd5fa9234b763df84dc937"'};
    'nanoserver' = @{ 'Dockerfile' = 'Dockerfile-windows-nanoserver' ; 'BuildArgs' = '--build-arg "FINAL_CONTAINER_TYPE=nanoserver"' };
    'nanoserver-jdk11' = @{ 'Dockerfile' = 'Dockerfile-windows-nanoserver' ; 'BuildArgs' = '--build-arg `"FINAL_CONTAINER_TYPE=nanoserver`" --build-arg `"JAVA_BASE_VERSION=11`" --build-arg "JAVA_VERSION=11.0.3-1" --build-arg "JAVA_ZIP_VERSION=11.0.3.7-1" --build-arg "JAVA_SHA256=b13703a7ee5ff3e14881b7d3488fa93942d1858ca3cd5fa9234b763df84dc937"' };
}

if(![System.String]::IsNullOrWhiteSpace($Build) -and ($builds.ContainsKey($Build) -or ($Build -eq 'default'))) {
    Write-Host "Building $Build => tag=$Tag"
    if($Build -eq 'default') {
        $Build = ''
    } 

    $type = $Build
    if($Build -ne '') {
        $type = "-$Build"
    }
    $cmd = "docker build -f {0} -t jenkins/agent-windows{1}:{2} {3} {4} ." -f $builds[$build]['Dockerfile'], $type, $Tag, $builds[$build]['BuildArgs'], $AdditionalArgs
    Invoke-Expression $cmd

} else {
    foreach($build in $builds.Keys) {
        $type = $build
        if($build -eq '') {
            Write-Host "Building default => tag=$Tag"
        } else {
            Write-Host "Building $build => tag=$Tag"
            $type = "-$build"
        }
        $cmd = "docker build -f {0} -t jenkins/agent-windows{1}:{2} {3} {4} ." -f $builds[$build]['Dockerfile'], $type, $Tag, $builds[$build]['BuildArgs'], $AdditionalArgs
        Invoke-Expression $cmd
        break
    }
}

Write-Host "Build finished successfully"
