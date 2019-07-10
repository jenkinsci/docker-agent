[CmdletBinding()]
Param(
    [String] $Tag = 'latest',
    [String] $AdditionalArgs = '',
    [String] $Build = ''
)

$builds = @{
    '' = @{ 'Dockerfile' = 'Dockerfile-windows' ; 'BuildArgs' = '--build-arg `"JAVA_BASE_VERSION=8u212-b04`"' };
    #'jdk11' = @{ 'Dockerfile' = 'Dockerfile-windows' ; 'BuildArgs' = '--build-arg `"JAVA_BASE_VERSION=11.0.3`"'};    
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
