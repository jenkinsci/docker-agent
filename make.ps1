[CmdletBinding()]
Param(
    [Parameter(Position=1)]
    [String] $Target = "build",
    [String] $AdditionalArgs = '',
    [String] $Build = '',
    [String] $Version = '4.3',
    [int] $WindowsTag = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ReleaseId
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
    'jdk8' = @{'Dockerfile' = 'Dockerfile-windows' ; 'Tags' = @( "latest", "windowsservercore-$WindowsTag", "jdk8", "windowsservercore-$WindowsTag-jdk8" ) };
    'jdk11' = @{'DockerFile' = 'Dockerfile-windows-jdk11'; 'Tags' = @( "windowsservercore-$WindowsTag-jdk11", "jdk11" ) };
    'nanoserver' = @{'DockerFile' = 'Dockerfile-windows-nanoserver'; 'Tags' = @( "nanoserver-$WindowsTag", "nanoserver-$WindowsTag-jdk8" ) };
    'nanoserver-jdk11' = @{'DockerFile' = 'Dockerfile-windows-nanoserver-jdk11'; 'Tags' = @( "nanoserver-$WindowsTag-jdk11" ) };
}

if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
    foreach($tag in $builds[$Build]['Tags']) {
        Write-Host "Building $Build => tag=$tag"
        $cmd = "docker build -f {0} --build-arg WINDOWS_DOCKER_TAG=$WindowsTag --build-arg VERSION='$Version' -t {1}/{2}:{3} {4} ." -f $builds[$Build]['Dockerfile'], $Organization, $Repository, $tag, $AdditionalArgs
        Invoke-Expression $cmd
    }
} else {
    foreach($b in $builds.Keys) {
        foreach($tag in $builds[$b]['Tags']) {
            Write-Host "Building $b => tag=$tag"
            $cmd = "docker build -f {0} --build-arg WINDOWS_DOCKER_TAG=$WindowsTag --build-arg VERSION='$Version' -t {1}/{2}:{3} {4} ." -f $builds[$b]['Dockerfile'], $Organization, $Repository, $tag, $AdditionalArgs
            Invoke-Expression $cmd
        }
    }

    Write-Host "Building $Build => tag=$tag"
    $cmd = "docker build -f {0} --build-arg WINDOWS_DOCKER_TAG=$WindowsTag --build-arg VERSION='$Version' -t {1}/{2}:{3} {4} ." -f $builds['default']['Dockerfile'], $Organization, $Repository, $Version, $AdditionalArgs
    Invoke-Expression $cmd
}

if($lastExitCode -ne 0) {
    exit $lastExitCode
}

if($target -eq "test") {
    $mod = Get-InstalledModule -Name Pester -Version 4.9.0 -ErrorAction SilentlyContinue
    if($null -eq $mod) {
        Install-Module -Force -Name Pester -Version 4.9.0 -Scope CurrentUser
    }

    if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
        $env:FLAVOR = $Build
        Invoke-Pester -Path tests -EnableExit
        Remove-Item env:\FLAVOR
    } else {
        foreach($b in $builds.Keys) {
            $env:FLAVOR = $b
            Invoke-Pester -Path tests -EnableExit
            Remove-Item env:\FLAVOR
        }
    }
}

if($target -eq "publish") {
    if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
        foreach($tag in $Builds[$Build]['Tags']) {
            Write-Host "Publishing $Build => tag=$tag"
            $cmd = "docker push {0}/{1}:{2}" -f $Organization, $Repository, $tag
            Invoke-Expression $cmd
        }
    } else {
        foreach($b in $builds.Keys) {
            foreach($tag in $Builds[$b]['Tags']) {
                Write-Host "Publishing $b => tag=$tag"
                $cmd = "docker push {0}/{1}:{2}" -f $Organization, $Repository, $tag
                Invoke-Expression $cmd
            }
        }

        Write-Host "Publishing $b => tag=$Version"
        $cmd = "docker push {0}/{1}:{2}" -f $Organization, $Repository, $Version
        Invoke-Expression $cmd
    }
}


if($lastExitCode -ne 0) {
    Write-Error "Build failed!"
} else {
    Write-Host "Build finished successfully"
}
exit $lastExitCode
