Import-Module -DisableNameChecking -Force $PSScriptRoot/test_helpers.psm1

$global:IMAGE_NAME = Get-EnvOrDefault 'IMAGE_NAME' ''
$global:VERSION = Get-EnvOrDefault 'VERSION' ''
$global:JAVA_VERSION = Get-EnvOrDefault 'JAVA_VERSION' ''

Write-Host "= TESTS: Preparing $global:IMAGE_NAME with Remoting $global:VERSION and Java $global:JAVA_VERSION"

$imageItems = $global:IMAGE_NAME.Split(':')
$GLOBAL:IMAGE_TAG = $imageItems[1]

$items = $global:IMAGE_TAG.Split('-')
# Remove the 'jdk' prefix
$global:JAVAMAJORVERSION = $items[0].Remove(0,3)
$global:WINDOWSFLAVOR = $items[1]
$global:WINDOWSVERSIONTAG = $items[2]
$global:WINDOWSVERSIONFALLBACKTAG = $items[2]
if ($items[2] -eq 'ltsc2019') {
    $global:WINDOWSVERSIONFALLBACKTAG = '1809'
}

# TODO: make this name unique for concurency
$global:CONTAINERNAME = 'pester-jenkins-agent-{0}' -f $global:IMAGE_TAG

$global:CONTAINERSHELL = 'powershell.exe'
if ($global:WINDOWSFLAVOR -eq 'nanoserver') {
    $global:CONTAINERSHELL = 'pwsh.exe'
}

$global:GITLFSVERSION = '3.5.1'

# # Uncomment to help debugging when working on this script
# Write-Host "= DEBUG: global vars"
# Get-Variable -Scope Global | ForEach-Object { Write-Host "$($_.Name) = $($_.Value)" }
# Write-Host "= DEBUG: env vars"
# Get-ChildItem Env: | ForEach-Object { Write-Host "$($_.Name) = $($_.Value)" }

Cleanup($global:CONTAINERNAME)

Describe "[$global:IMAGE_NAME] image is present" {
    It 'inspects image' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "inspect $global:IMAGE_NAME"
        $exitCode | Should -Be 0
    }
}

Describe "[$global:IMAGE_NAME] correct image metadata" {
    It 'has correct volumes' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "inspect --format='{{.Config.Volumes}}' $global:IMAGE_NAME"
        $stdout = $stdout.Trim()
        $stdout | Should -Match 'C:/Users/jenkins/.jenkins'
        $stdout | Should -Match 'C:/Users/jenkins/Work'
    }
}

Describe "[$global:IMAGE_NAME] image has correct applications in the PATH" {
    BeforeAll {
        docker run --detach --interactive --tty --name "$global:CONTAINERNAME" "$global:IMAGE_NAME" "$global:CONTAINERSHELL"
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
    }

    It 'has java installed and in the path' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"if (`$null -eq (Get-Command java.exe -ErrorAction SilentlyContinue)) { exit -1 } else { exit 0 }`""
        $exitCode | Should -Be 0
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"`$global:VERSION = java -version 2>&1 ; Write-Host `$global:VERSION`""
        $r = [regex] "^openjdk version `"(?<major>\d+)"
        $m = $r.Match($stdout)
        $m | Should -Not -Be $null
        $m.Groups['major'].ToString() | Should -Be $global:JAVAMAJORVERSION
    }

    It 'has AGENT_WORKDIR in the environment' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"Get-ChildItem env:`""
        $exitCode | Should -Be 0
        $stdout.Trim() | Should -Match 'AGENT_WORKDIR.*C:/Users/jenkins/Work'
    }

    It 'has user in the environment' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"Get-ChildItem env:`""
        $exitCode | Should -Be 0
        $stdout.Trim() | Should -Match 'user.*jenkins'
    }

    It 'has git-lfs (and thus git) installed' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"`& git lfs version`""
        $exitCode | Should -Be 0
        $stdout.Trim() | Should -Match "git-lfs/${global:GITLFSVERSION}"
    }

    It 'does not include jenkins-agent.ps1 (inbound-agent)' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"if (Test-Path C:/ProgramData/Jenkins/jenkins-agent.ps1) { exit -1 } else { exit 0 }`""
        $exitCode | Should -Be 0
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
    }
}

Describe "[$global:IMAGE_NAME] check user account" {
    BeforeAll {
        docker run -d -it --name "$global:CONTAINERNAME" -P "$global:IMAGE_NAME" "$global:CONTAINERSHELL"
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
    }

    It 'Password never expires' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"if ((net user jenkins | Select-String -Pattern 'Password expires') -match 'Never') { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'Password not required' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"if ((net user jenkins | Select-String -Pattern 'Password required') -match 'No') { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
    }
}

Describe "[$global:IMAGE_NAME] check user access to directories" {
    BeforeAll {
        docker run -d -it --name "$global:CONTAINERNAME" -P "$global:IMAGE_NAME" "$global:CONTAINERSHELL"
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
    }

    It 'can write to HOME' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"New-Item -ItemType File -Path C:/Users/jenkins/a.txt | Out-Null ; if (Test-Path C:/Users/jenkins/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'can write to HOME/.jenkins' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"New-Item -ItemType File -Path C:/Users/jenkins/.jenkins/a.txt | Out-Null ; if (Test-Path C:/Users/jenkins/.jenkins/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'can write to HOME/Work' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"New-Item -ItemType File -Path C:/Users/jenkins/Work/a.txt | Out-Null ; if (Test-Path C:/Users/jenkins/Work/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
    }
}

$global:TEST_VERSION = '4.0'
$global:TEST_USER = 'test-user'
$global:TEST_AGENT_WORKDIR = 'C:/test-user/something'

Describe "[$global:IMAGE_NAME] can be built with custom build arguments" {
    BeforeAll {
        Push-Location -StackName 'agent' -Path "$PSScriptRoot/.."

        $exitCode, $stdout, $stderr = Run-Program 'docker' "build --target agent --build-arg `"VERSION=${global:TEST_VERSION}`" --build-arg `"JAVA_VERSION=${global:JAVA_VERSION}`" --build-arg `"JAVA_HOME=C:\openjdk-${global:JAVAMAJORVERSION}`" --build-arg `"WINDOWS_VERSION_TAG=${global:WINDOWSVERSIONTAG}`" --build-arg `"TOOLS_WINDOWS_VERSION=${global:WINDOWSVERSIONFALLBACKTAG}`" --build-arg `"user=${global:TEST_USER}`" --build-arg `"AGENT_WORKDIR=${global:TEST_AGENT_WORKDIR}`" --tag ${global:IMAGE_NAME} --file ./windows/${global:WINDOWSFLAVOR}/Dockerfile ."
        $exitCode | Should -Be 0

        $exitCode, $stdout, $stderr = Run-Program 'docker' "run -d -it --name $global:CONTAINERNAME -P $global:IMAGE_NAME $global:CONTAINERSHELL"
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
    }

    It 'has the correct version of remoting' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"`$global:VERSION = java -jar C:/ProgramData/Jenkins/agent.jar -version ; Write-Host `$global:VERSION`""
        $exitCode | Should -Be 0
        $stdout.Trim() | Should -Match $global:TEST_VERSION
    }

    It 'has correct user' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"(Get-ChildItem env:\ | Where-Object { `$_.Name -eq 'USERNAME' }).Value`""
        $exitCode | Should -Be 0
        $stdout.Trim() | Should -Match $global:TEST_USER
    }

    It 'has correct AGENT_WORKDIR' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"Get-ChildItem env:`""
        $exitCode | Should -Be 0
        $stdout | Should -Match "AGENT_WORKDIR.*${global:TEST_AGENT_WORKDIR}"
    }

    It 'can write to HOME' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"New-Item -ItemType File -Path C:/Users/${TEST_USER}/a.txt | Out-Null ; if (Test-Path C:/Users/${TEST_USER}/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'can write to HOME/.jenkins' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"New-Item -ItemType File -Path C:/Users/${TEST_USER}/.jenkins/a.txt | Out-Null ; if (Test-Path C:/Users/${TEST_USER}/.jenkins/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'can write to HOME/Work' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"New-Item -ItemType File -Path ${TEST_AGENT_WORKDIR}/a.txt | Out-Null ; if (Test-Path ${TEST_AGENT_WORKDIR}/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'version in docker metadata' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "inspect --format=`"{{index .Config.Labels \`"org.opencontainers.image.version\`"}}`" $global:IMAGE_NAME"
        $exitCode | Should -Be 0
        $stdout.Trim() | Should -Match $global:sTEST_VERSION
    }

    AfterAll {
        Pop-Location -StackName 'agent'
        Cleanup($global:CONTAINERNAME)
    }
}
