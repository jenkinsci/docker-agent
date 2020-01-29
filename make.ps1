[CmdletBinding()]
Param(
    [Parameter(Position=1)]
    [String] $target = "build",
    [String] $TagPrefix = 'latest',
    [String] $AdditionalArgs = '',
    [String] $Build = '',
    [String] $Flavor = ''
)

$Repository = 'agent'
$Organization = 'jenkins'

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_REPO)) {
    $Repository = $env:DOCKERHUB_REPO
}

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_ORGANISATION)) {
    $Organization = $env:DOCKERHUB_ORGANISATION
}

$builds = @{
    'jdk8' = @{
        'nanoserver' = @{ 'Folder' = '8\windows\nanoserver-1809'; 'TagSuffix' = '-nanoserver' };
        'servercore' = @{ 'Folder' = '8\windows\servercore-1809'; 'TagSuffix' = '-windows' };
    };
    'jdk11' = @{
        'nanoserver' = @{ 'Folder' = '11\windows\nanoserver-1809'; 'TagSuffix' = '-nanoserver-jdk11' };
        'servercore' = @{ 'Folder' = '11\windows\servercore-1809'; 'TagSuffix' = '-windows-jdk11' };
    };
}

function Build-Image([String] $JdkVersion, [String] $Flavor, [String] $TagSuffix, [String] $Folder) {
    Write-Host "Building $JdkVersion => flavor=$Flavor tag=$TagPrefix$TagSuffix)"
    $cmd = "docker build -t {0}/{1}:{2}{3} {4} {5}" -f $Organization, $Repository, $TagPrefix, $TagSuffix, $AdditionalArgs, $Folder
    Invoke-Expression $cmd
}

function Publish-Image([String] $JdkVersion, [String] $Flavor, [String] $TagSuffix) {
    Write-Host "Publishing $JdkVersion => flavor=$Flavor tag=$TagPrefix$TagSuffix"
    $cmd = "docker push {0}/{1}:{2}{3}" -f $Organization, $Repository, $TagPrefix, $TagSuffix
    Invoke-Expression $cmd
}

if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build) ) {
    if(![System.String]::IsNullOrWhiteSpace($Flavor) -and $builds[$Build].ContainsKey($Flavor)){
        Build-Image $Build $Flavor $builds[$Build][$Flavor]['TagSuffix'] $builds[$Build][$Flavor]['Folder']
    } else {
        foreach($Flavor in $builds[$Build].Keys){
            Build-Image $Build $Flavor $builds[$Build][$Flavor]['TagSuffix'] $builds[$Build][$Flavor]['Folder']
        }
    }
} else {
    foreach($Build in $builds.Keys) {
        foreach($Flavor in $builds[$Build].Keys) {
            Build-Image $Build $Flavor $builds[$Build][$Flavor]['TagSuffix'] $builds[$Build][$Flavor]['Folder']
        }
    }
}

if($lastExitCode -ne 0) {
    exit $lastExitCode
}

if($target -eq "publish") {
    if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
        if(![System.String]::IsNullOrWhiteSpace($Flavor) -and $builds[$Build].ContainsKey($Flavor)) {
            Publish-Image $Build $Flavor $builds[$Build][$Flavor]['TagSuffix']
        } else {
            foreach($Flavor in $builds[$Build].Keys){
                Publish-Image $Build $Flavor $builds[$Build][$Flavor]['TagSuffix']
            }
        }
    } else {
        foreach($Build in $builds.Keys) {
            foreach($Flavor in $builds[$Build].Keys) {
                Build-Image $Build $Flavor $builds[$Build][$Flavor]['TagSuffix']
            }
        }
    }
}

if($lastExitCode -ne 0) {
    Write-Error "Build failed!"
} else {
    Write-Host "Build finished successfully"
}
exit $lastExitCode
