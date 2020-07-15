[CmdletBinding()]
Param(
    [Parameter(Position=1)]
    [String] $Target = "build",
    [String] $AdditionalArgs = '',
    [String] $Build = '',
    [String] $RemotingVersion = '4.3',
    [String] $BuildNumber = "1",
    [switch] $PushVersions = $false
)

$Repository = 'agent'
$Organization = 'jenkins'

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_REPO)) {
    $Repository = $env:DOCKERHUB_REPO
}

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_ORGANISATION)) {
    $Organization = $env:DOCKERHUB_ORGANISATION
}


# this is the jdk version that will be used for the 'bare tag' images, e.g., jdk8-windowsservercore-1809 -> windowsserver-1809
$defaultBuild = '8'
$builds = @{}

Get-ChildItem -Recurse -Include windows -Directory | ForEach-Object {
    Get-ChildItem -Directory -Path $_ | ForEach-Object {
        $dir = $_.FullName.Replace((Get-Location), "").TrimStart("\")
        $items = $dir.Split("\")
        $jdkVersion = $items[0]
        $baseImage = $items[2]
        $basicTag = "jdk${jdkVersion}-${baseImage}" 
        $tags = @( $basicTag )
        if($jdkVersion -eq $defaultBuild) {
            $tags += $baseImage
        }

        $builds[$basicTag] = @{
            'Folder' = $dir;
            'Tags' = $tags;
        }        
    }
}

if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
    foreach($tag in $builds[$Build]['Tags']) {
        Write-Host "Building $Build => tag=$tag"
        $cmd = "docker build --build-arg VERSION='$RemotingVersion' -t {0}/{1}:{2} {3} {4}" -f $Organization, $Repository, $tag, $AdditionalArgs, $builds[$Build]['Folder']
        Invoke-Expression $cmd

        if($PushVersions) {
            $buildTag = "$RemotingVersion-$BuildNumber-$tag"
            if($tag -eq 'latest') {
                $buildTag = "$RemotingVersion-$BuildNumber"
            }
            Write-Host "Building $Build => tag=$buildTag"
            $cmd = "docker build --build-arg VERSION='$RemotingVersion' -t {0}/{1}:{2} {3} {4}" -f $Organization, $Repository, $buildTag, $AdditionalArgs, $builds[$Build]['Folder']
            Invoke-Expression $cmd
        }
    }
} else {
    foreach($b in $builds.Keys) {
        foreach($tag in $builds[$b]['Tags']) {
            Write-Host "Building $b => tag=$tag"
            $cmd = "docker build --build-arg VERSION='$RemotingVersion' -t {0}/{1}:{2} {3} {4}" -f $Organization, $Repository, $tag, $AdditionalArgs, $builds[$b]['Folder']
            Invoke-Expression $cmd

            if($PushVersions) {
                $buildTag = "$RemotingVersion-$BuildNumber-$tag"
                if($tag -eq 'latest') {
                    $buildTag = "$RemotingVersion-$BuildNumber"
                }
                Write-Host "Building $Build => tag=$buildTag"
                $cmd = "docker build --build-arg VERSION='$RemotingVersion' -t {0}/{1}:{2} {3} {4}" -f $Organization, $Repository, $buildTag, $AdditionalArgs, $builds[$b]['Folder']
                Invoke-Expression $cmd
            }
        }
    }
}

if($lastExitCode -ne 0) {
    exit $lastExitCode
}

if($target -eq "test") {
    $mod = Get-InstalledModule -Name Pester -MinimumVersion 4.9.0 -MaximumVersion 4.99.99 -ErrorAction SilentlyContinue
    if($null -eq $mod) {
        $module = "c:\Program Files\WindowsPowerShell\Modules\Pester"
        if(Test-Path $module) {
            takeown /F $module /A /R
            icacls $module /reset
            icacls $module /grant Administrators:'F' /inheritance:d /T
            Remove-Item -Path $module -Recurse -Force -Confirm:$false
        }
        Install-Module -Force -Name Pester -MaximumVersion 4.99.99
    }

    if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
        $env:FOLDER = $builds[$Build]['Folder']
        $env:VERSION = "$RemotingVersion-$BuildNumber"
        Invoke-Pester -Path tests -EnableExit
        Remove-Item env:\FOLDER
        Remove-Item env:\VERSION
    } else {
        foreach($b in $builds.Keys) {
            $env:FOLDER = $builds[$b]['Folder']
            $env:VERSION = "$RemotingVersion-$BuildNumber"
            Invoke-Pester -Path tests -EnableExit
            Remove-Item env:\FOLDER
            Remove-Item env:\VERSION
        }
    }
}

if($target -eq "publish") {
    if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
        foreach($tag in $Builds[$Build]['Tags']) {
            Write-Host "Publishing $Build => tag=$tag"
            $cmd = "docker push {0}/{1}:{2}" -f $Organization, $Repository, $tag
            Invoke-Expression $cmd

            if($PushVersions) {
                $buildTag = "$RemotingVersion-$BuildNumber-$tag"
                if($tag -eq 'latest') {
                    $buildTag = "$RemotingVersion-$BuildNumber"
                }
                Write-Host "Publishing $Build => tag=$buildTag"
                $cmd = "docker push {0}/{1}:{2}" -f $Organization, $Repository, $buildTag
                Invoke-Expression $cmd
            }
        }
    } else {
        foreach($b in $builds.Keys) {
            foreach($tag in $Builds[$b]['Tags']) {
                Write-Host "Publishing $b => tag=$tag"
                $cmd = "docker push {0}/{1}:{2}" -f $Organization, $Repository, $tag
                Invoke-Expression $cmd

                if($PushVersions) {
                    $buildTag = "$RemotingVersion-$BuildNumber-$tag"
                    if($tag -eq 'latest') {
                        $buildTag = "$RemotingVersion-$BuildNumber"
                    }
                    Write-Host "Publishing $Build => tag=$buildTag"
                    $cmd = "docker push {0}/{1}:{2}" -f $Organization, $Repository, $buildTag
                    Invoke-Expression $cmd
                }
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
