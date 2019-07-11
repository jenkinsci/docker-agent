[CmdletBinding()]
Param(
    [String] $TagPrefix = 'latest',
    [String] $AdditionalArgs = '',
    [String] $Build = '',
    [String] $Repository = 'jenkins4eval'
)

$builds = @{
    'default' = @{'Dockerfile' = 'Dockerfile-windows' ; 'TagSuffix' = '-windows' };
    'jdk11' = @{'DockerFile' = 'Dockerfile-windows-jdk11'; 'TagSuffix' = '-windows-jdk11' };
    #'nanoserver' = 'Dockerfile-windows-nanoserver';
    #'nanoserver-jdk11' = 'Dockerfile-windows-nanoserver-jdk11';
}

if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
    Write-Host "Building $build => tag=$TagPrefix$($builds[$build]['TagSuffix'])"
    $cmd = "docker build -f {0} -t {1}/agent:{2}{3} {4} ." -f $builds[$build]['Dockerfile'], $Repository, $TagPrefix, $builds[$build]['TagSuffix'], $AdditionalArgs
    Invoke-Expression $cmd
} else {
    foreach($build in $builds.Keys) {
        Write-Host "Building $build => tag=$TagPrefix$($builds[$build]['TagSuffix'])"
        $cmd = "docker build -f {0} -t {1}/agent:{2}{3} {4} ." -f $builds[$build]['Dockerfile'], $Repository, $TagPrefix, $builds[$build]['TagSuffix'], $AdditionalArgs
        Invoke-Expression $cmd
    }
}

Write-Host "Build finished successfully"
