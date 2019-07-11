[CmdletBinding()]
Param(
    [String] $Tag = 'latest',
    [String] $AdditionalArgs = '',
    [String] $Build = '',
    [String] $Repository = 'jenkins4eval'
)

$builds = @{
    'default' = 'Dockerfile-windows' ;
    'jdk11' = 'Dockerfile-windows-jdk11';
    'nanoserver' = 'Dockerfile-windows-nanoserver';
    'nanoserver-jdk11' = 'Dockerfile-windows-nanoserver-jdk11';
}

if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
    Write-Host "Building $Build => tag=$Tag"
    $type = ''
    if($Build -ne 'default') {
        $type = "-$Build"
    }
    $cmd = "docker build -f {0} -t {1}/agent-windows{2}:{3} {4} ." -f $builds[$build], $Repository, $type, $Tag, $AdditionalArgs
    Invoke-Expression $cmd
} else {
    foreach($build in $builds.Keys) {
        $type = ''
        Write-Host "Building $build => tag=$Tag"
        if($build -ne 'default') {
            $type = "-$build"
        }
        $cmd = "docker build -f {0} -t {1}/agent-windows{2}:{3} {4} ." -f $builds[$build], $Repository, $type, $Tag, $AdditionalArgs
        Invoke-Expression $cmd
    }
}

Write-Host "Build finished successfully"
