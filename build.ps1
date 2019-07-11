[CmdletBinding()]
Param(
    [String] $Tag = 'latest',
    [String] $AdditionalArgs = '',
    [String] $Build = ''
)

$builds = @{
    'default' = @{ 'Dockerfile' = 'Dockerfile-windows' ; 'BuildArgs' = '' };
    'jdk11' = @{ 'Dockerfile' = 'Dockerfile-windows' ; 'BuildArgs' = '--build-arg `"JAVA_BASE_VERSION=11`"'};    
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
        Write-Host "Building $build => tag=$Tag"
        if($build -ne 'default') {
            $type = "-$build"
        }
        $cmd = "docker build -f {0} -t jenkins/agent-windows{1}:{2} {3} {4} ." -f $builds[$build]['Dockerfile'], $type, $Tag, $builds[$build]['BuildArgs'], $AdditionalArgs
        Invoke-Expression $cmd
        break
    }
}

Write-Host "Build finished successfully"
