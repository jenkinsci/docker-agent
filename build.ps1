[CmdletBinding()]
Param(
    [Parameter(Position=1)]
    [String] $Target = "build",
    [String] $RemotingVersion = '3206.vb_15dcf73f6a_9',
    [String] $AgentType = '',
    [String] $BuildNumber = '1',
    [switch] $DisableEnvProps = $false,
    [switch] $DryRun = $false
)

$ErrorActionPreference = 'Stop'
$AgentTypes = @('agent', 'inbound-agent')
if ($AgentType -ne '' -and $AgentType -in $AgentTypes) {
    $AgentTypes = @($AgentType)
}
$ImageType = 'windowsservercore-ltsc2019'
$Organisation = 'jenkins4eval'
$AgentRepository = 'agent'
$InboundAgentRepository = 'inbound-agent'

if(!$DisableEnvProps) {
    Get-Content env.props | ForEach-Object {
        $items = $_.Split("=")
        if($items.Length -eq 2) {
            $name = $items[0].Trim()
            $value = $items[1].Trim()
            Set-Item -Path "env:$($name)" -Value $value
        }
    }
}

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_ORGANISATION)) {
    $Organisation = $env:DOCKERHUB_ORGANISATION
}

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_REPO_AGENT)) {
    $AgentRepository = $env:DOCKERHUB_REPO_AGENT
}

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_REPO_INBOUND_AGENT)) {
    $InboundAgentRepository = $env:DOCKERHUB_REPO_INBOUND_AGENT
}

if(![String]::IsNullOrWhiteSpace($env:REMOTING_VERSION)) {
    $RemotingVersion = $env:REMOTING_VERSION
}

if(![String]::IsNullOrWhiteSpace($env:IMAGE_TYPE)) {
    $ImageType = $env:IMAGE_TYPE
}

# Check for required commands
Function Test-CommandExists {
    # From https://devblogs.microsoft.com/scripting/use-a-powershell-function-to-see-if-a-command-exists/
    Param (
        [String] $command
    )

    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    try {
        if(Get-Command $command){
            Write-Debug "$command exists"
        }
    }
    Catch {
        "$command does not exist"
    }
    Finally {
        $ErrorActionPreference=$oldPreference
    }
}

# this is the jdk version that will be used for the 'bare tag' images, e.g., jdk17-windowsservercore-1809 -> windowsserver-1809
$defaultJdk = '17'
$env:REMOTING_VERSION = "$RemotingVersion"

$items = $ImageType.Split("-")
$env:WINDOWS_FLAVOR = $items[0]
$env:WINDOWS_VERSION_TAG = $items[1]
$env:TOOLS_WINDOWS_VERSION = $items[1]
if ($items[1] -eq 'ltsc2019') {
    # There are no eclipse-temurin:*-ltsc2019 or mcr.microsoft.com/powershell:*-ltsc2019 docker images unfortunately, only "1809" ones
    $env:TOOLS_WINDOWS_VERSION = '1809'
}

$ProgressPreference = 'SilentlyContinue' # Disable Progress bar for faster downloads

Test-CommandExists "docker"
Test-CommandExists "docker-compose"
Test-CommandExists "yq"

function Test-Image {
    param (
        $AgentTypeAndImageName
    )

    $items = $AgentTypeAndImageName.Split("|")
    $agentType = $items[0]
    $imageName = $items[1]

    Write-Host "= TEST: Testing ${agentType} image ${imageName}:"

    $env:AGENT_TYPE = $agentType
    $env:AGENT_IMAGE = $imageName
    $env:VERSION = "$RemotingVersion-$BuildNumber"

    $targetPath = '.\target\{0}\{1}' -f $agentType, $imageName
    if(Test-Path $targetPath) {
        Remove-Item -Recurse -Force $targetPath
    }
    New-Item -Path $targetPath -Type Directory | Out-Null
    $configuration.Run.Path = 'tests\{0}.Tests.ps1' -f $agentType
    $configuration.TestResult.OutputPath = '{0}\junit-results.xml' -f $targetPath
    $TestResults = Invoke-Pester -Configuration $configuration
    if ($TestResults.FailedCount -gt 0) {
        Write-Host "There were $($TestResults.FailedCount) failed tests in ${agentType} $imageName"
        $testFailed = $true
    } else {
        Write-Host "There were $($TestResults.PassedCount) passed tests out of $($TestResults.TotalCount) in ${agentType} $imageName"
    }

    Remove-Item env:\AGENT_TYPE
    Remove-Item env:\AGENT_IMAGE
    Remove-Item env:\VERSION
}

function Publish-Image {
    param (
        [String] $Build,
        [String] $ImageName
    )
    if ($DryRun) {
        Write-Host "= PUBLISH: (dry-run) docker tag then publish '$Build $ImageName'"
    } else {
        Write-Host "= PUBLISH: Tagging $Build => full name = $ImageName"
        docker tag "$Build" "$ImageName"

        Write-Host "= PUBLISH: Publishing $ImageName..."
        docker push "$ImageName"
    }
}


$originalDockerComposeFile = 'build-windows.yaml'
$finalDockerComposeFile = 'build-windows-current.yaml'
$baseDockerCmd = 'docker-compose --file={0}' -f $finalDockerComposeFile
$baseDockerBuildCmd = '{0} build --parallel --pull' -f $baseDockerCmd

foreach($agentType in $AgentTypes) {
    $env:AGENT_TYPE = $agentType

    # Temporary docker compose file (git ignored)
    Copy-Item -Path $originalDockerComposeFile -Destination $finalDockerComposeFile
    $repository = $InboundAgentRepository
    # If it's a type "agent", set corresponding target and repository
    if($agentType -eq 'agent') {
        yq '.services.[].build.target = \"agent\"' $originalDockerComposeFile | Out-File -FilePath $finalDockerComposeFile
        $repository = $AgentRepository
    }

    $builds = @{}

    Invoke-Expression "$baseDockerCmd config --services" 2>$null | ForEach-Object {
        $image = '{0}-{1}-{2}' -f $_, $env:WINDOWS_FLAVOR, $env:WINDOWS_VERSION_TAG # Ex: "jdk17-nanoserver-1809"

        # Remove the 'jdk' prefix
        $jdkMajorVersion = $_.Remove(0,3)

        $versionTag = "${RemotingVersion}-${BuildNumber}-${image}"
        $tags = @( $image, $versionTag )

        # Additional image tag without any 'jdk' prefix for the default JDK
        $baseImage = "${env:WINDOWS_FLAVOR}-${env:WINDOWS_VERSION_TAG}"
        if($jdkMajorVersion -eq "$defaultJdk") {
            $tags += $baseImage
            $tags += "${RemotingVersion}-${BuildNumber}-${baseImage}"
        }

        $builds[$image] = @{
            'Tags' = $tags;
        }
    }

    Write-Host "= PREPARE: List of $Organisation/$repository images and tags to be processed:"
    ConvertTo-Json $builds

    Write-Host "= BUILD: Building all images..."
    if ($DryRun) {
        Write-Host "(dry-run) $baseDockerBuildCmd"
    } else {
        Invoke-Expression $baseDockerBuildCmd
    }
    Write-Host "= BUILD: Finished building all images."

    if($lastExitCode -ne 0) {
        exit $lastExitCode
    }

    if($target -eq "test") {
        if ($DryRun) {
            Write-Host "= TEST: (dry-run) test harness"
        } else {
            Write-Host "= TEST: Starting test harness"

            # Only fail the run afterwards in case of any test failures
            $testFailed = $false
            $mod = Get-InstalledModule -Name Pester -MinimumVersion 5.3.0 -MaximumVersion 5.3.3 -ErrorAction SilentlyContinue
            if($null -eq $mod) {
                Write-Host "= TEST: Pester 5.3.x not found: installing..."
                $module = "c:\Program Files\WindowsPowerShell\Modules\Pester"
                if(Test-Path $module) {
                    takeown /F $module /A /R
                    icacls $module /reset
                    icacls $module /grant Administrators:'F' /inheritance:d /T
                    Remove-Item -Path $module -Recurse -Force -Confirm:$false
                }
                Install-Module -Force -Name Pester -MaximumVersion 5.3.3
            }

            Import-Module Pester
            Write-Host "= TEST: Setting up Pester environment..."
            $configuration = [PesterConfiguration]::Default
            $configuration.Run.PassThru = $true
            $configuration.Run.Path = '.\tests'
            $configuration.Run.Exit = $true
            $configuration.TestResult.Enabled = $true
            $configuration.TestResult.OutputFormat = 'JUnitXml'
            $configuration.Output.Verbosity = 'Diagnostic'
            $configuration.CodeCoverage.Enabled = $false

            Write-Host "= TEST: Testing all images..."
            Write-Host "= TEST: Testing all ${agentType} images..."
            foreach($image in $builds.Keys) {
                Test-Image ('{0}|{1}' -f $agentType, $image)
            }

            # Fail if any test failures
            if($testFailed -ne $false) {
                Write-Error "Test stage failed for ${agentType}!"
                exit 1
            } else {
                Write-Host "= TEST: stage passed for ${agentType}!"
            }
        }
    }

    if($target -eq "publish") {
        # Only fail the run afterwards in case of any issues when publishing the docker images
        $publishFailed = 0
        foreach($b in $builds.Keys) {
            foreach($tag in $Builds[$b]['Tags']) {
                Publish-Image "$b" "${Organisation}/${Repository}:${tag}"
                if($lastExitCode -ne 0) {
                    $publishFailed = 1
                }
            }
        }

        # Fail if any issues when publising the docker images
        if($publishFailed -ne 0) {
            Write-Error "Publish failed for ${Organisation}/${repository}!"
            exit 1
        }
    }
}

if($lastExitCode -ne 0) {
    Write-Error "Build failed!"
} else {
    Write-Host "Build finished successfully"
}
exit $lastExitCode
