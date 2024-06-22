[CmdletBinding()]
Param(
    [Parameter(Position=1)]
    [String] $Target = "build",
    [String] $RemotingVersion = '3256.v88a_f6e922152',
    [String] $AgentType = '',
    [String] $BuildNumber = '1',
    [switch] $DisableEnvProps = $false,
    [switch] $DryRun = $false,
    # Output debug info for tests. Accepted values:
    # - empty (no additional test output)
    # - 'debug' (test cmd & stderr outputed)
    # - 'verbose' (test cmd, stderr, stdout outputed)
    [String] $TestsDebug = ''
)

$ErrorActionPreference = 'Stop'

$originalDockerComposeFile = 'build-windows.yaml'
$finalDockerComposeFile = 'build-windows-current.yaml'
$baseDockerCmd = 'docker-compose --file={0}' -f $finalDockerComposeFile
$baseDockerBuildCmd = '{0} build --parallel --pull' -f $baseDockerCmd

$AgentTypes = @('agent', 'inbound-agent')
if ($AgentType -ne '' -and $AgentType -in $AgentTypes) {
    $AgentTypes = @($AgentType)
}
$ImageType = 'windowsservercore-ltsc2019'
$Organisation = 'jenkins4eval'
$Repository = @{
    'agent' = 'agent'
    'inbound-agent' = 'inbound-agent'
}

if(![String]::IsNullOrWhiteSpace($env:TESTS_DEBUG)) {
    $TestsDebug = $env:TESTS_DEBUG
}
$env:TESTS_DEBUG = $TestsDebug

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
    $Repository['agent'] = $env:DOCKERHUB_REPO_AGENT
}

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_REPO_INBOUND_AGENT)) {
    $Repository['inbound-agent'] = $env:DOCKERHUB_REPO_INBOUND_AGENT
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

# Ensure constant env vars used in the docker compose file are defined
$env:DOCKERHUB_ORGANISATION = "$Organisation"
$env:REMOTING_VERSION = "$RemotingVersion"
$env:BUILD_NUMBER = $BuildNumber

$items = $ImageType.Split("-")
$env:WINDOWS_FLAVOR = $items[0]
$env:WINDOWS_VERSION_TAG = $items[1]
$env:TOOLS_WINDOWS_VERSION = $items[1]
if ($items[1] -eq 'ltsc2019') {
    # There are no mcr.microsoft.com/powershell:*-ltsc2019 docker images unfortunately, only "1809" ones
    $env:TOOLS_WINDOWS_VERSION = '1809'
    # Workaround for 2019 only until https://github.com/microsoft/Windows-Containers/issues/493 is solved
    $env:WINDOWS_VERSION_DIGEST = '@sha256:6fdf140282a2f809dae9b13fe441635867f0a27c33a438771673b8da8f3348a4'
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
    $javaVersion = $items[2]
    $imageNameItems = $imageName.Split(":")
    $imageTag = $imageNameItems[1]

    Write-Host "= TEST: Testing ${imageName} image:"

    $env:IMAGE_NAME = $imageName
    $env:VERSION = "$RemotingVersion"
    $env:JAVA_VERSION = "$javaVersion"

    $targetPath = '.\target\{0}\{1}' -f $agentType, $imageTag
    if(Test-Path $targetPath) {
        Remove-Item -Recurse -Force $targetPath
    }
    New-Item -Path $targetPath -Type Directory | Out-Null
    $configuration.Run.Path = 'tests\{0}.Tests.ps1' -f $agentType
    $configuration.TestResult.OutputPath = '{0}\junit-results.xml' -f $targetPath
    $TestResults = Invoke-Pester -Configuration $configuration
    $failed = $false
    if ($TestResults.FailedCount -gt 0) {
        Write-Host "There were $($TestResults.FailedCount) failed tests out of $($TestResults.TotalCount) in ${imageName}"
        $failed = $true
    } else {
        Write-Host "There were $($TestResults.PassedCount) passed tests in ${imageName}"
    }

    Remove-Item env:\IMAGE_NAME
    Remove-Item env:\VERSION
    Remove-Item env:\JAVA_VERSION

    return $failed
}

foreach($agentType in $AgentTypes) {
    # Ensure remaining env vars used in the docker compose file are defined
    $env:AGENT_TYPE = $agentType
    $env:DOCKERHUB_REPO = $Repository[$agentType]

    # Temporary docker compose file (git ignored)
    Copy-Item -Path $originalDockerComposeFile -Destination $finalDockerComposeFile
    # If it's an "agent" type, add the corresponding target
    if($agentType -eq 'agent') {
        yq '.services.[].build.target = \"agent\"' $originalDockerComposeFile | Out-File -FilePath $finalDockerComposeFile
    }

    Write-Host "= PREPARE: List of $Organisation/$env:DOCKERHUB_REPO images and tags to be processed:"
    Invoke-Expression "$baseDockerCmd config"

    Write-Host "= BUILD: Building all images..."
    switch ($DryRun) {
        $true { Write-Host "(dry-run) $baseDockerBuildCmd" }
        $false { Invoke-Expression $baseDockerBuildCmd }
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

            Write-Host "= TEST: Testing all ${agentType} images..."
            # Only fail the run afterwards in case of any test failures
            $testFailed = $false
            $jdks = Invoke-Expression "$baseDockerCmd config" | yq -r --output-format json '.services' | ConvertFrom-Json
            foreach ($jdk in $jdks.PSObject.Properties) {
                $testFailed = $testFailed -or (Test-Image ('{0}|{1}|{2}' -f $agentType, $jdk.Value.image, $jdk.Value.build.args.JAVA_VERSION))
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
        Write-Host "= PUBLISH: push all images and tags"
        switch($DryRun) {
            $true { Write-Host "(dry-run) $baseDockerCmd push" }
            $false { Invoke-Expression "$baseDockerCmd push" }
        }

        # Fail if any issues when publising the docker images
        if($lastExitCode -ne 0) {
            Write-Error "= PUBLISH: failed!"
            exit 1
        }
    }
}

if($lastExitCode -ne 0) {
    Write-Error "Build failed!"
} else {
    Write-Host "= Build finished successfully"
}
exit $lastExitCode
