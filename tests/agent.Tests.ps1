Import-Module -DisableNameChecking -Force $PSScriptRoot/test_helpers.psm1

$global:AGENT_TYPE = Get-EnvOrDefault 'AGENT_TYPE' ''
$global:AGENT_IMAGE = Get-EnvOrDefault 'AGENT_IMAGE' ''
$global:VERSION = Get-EnvOrDefault 'VERSION' ''

$items = $global:AGENT_IMAGE.Split("-")

# Remove the 'jdk' prefix
$global:JAVAMAJORVERSION = $items[0].Remove(0,3)
$global:WINDOWSFLAVOR = $items[1]
$global:WINDOWSVERSIONTAG = $items[2]
$global:WINDOWSVERSIONFALLBACKTAG = $items[2]
if ($items[2] -eq 'ltsc2019') {
    $global:WINDOWSVERSIONFALLBACKTAG = '1809'
}

# TODO: make this name unique for concurency
$global:CONTAINERNAME = 'pester-jenkins-agent-{0}' -f $global:AGENT_IMAGE

$global:CONTAINERSHELL="powershell.exe"
if($global:WINDOWSFLAVOR -eq 'nanoserver') {
    $global:CONTAINERSHELL = "pwsh.exe"
}

$global:GITLFSVERSION = '3.4.1'

Cleanup($global:CONTAINERNAME)

Describe "[$global:AGENT_TYPE > $global:AGENT_IMAGE] image is present" {
    It 'builds image' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "inspect $global:AGENT_IMAGE"
        $exitCode | Should -Be 0
    }
}

Describe "[$global:AGENT_TYPE > $global:AGENT_IMAGE] correct image metadata" {
    It 'has correct volumes' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "inspect --format='{{.Config.Volumes}}' $global:AGENT_IMAGE"
        $stdout = $stdout.Trim()
        $stdout | Should -Match 'C:/Users/jenkins/.jenkins'
        $stdout | Should -Match 'C:/Users/jenkins/Work'
    }
}

Describe "[$global:AGENT_TYPE > $global:AGENT_IMAGE] image has correct applications in the PATH" {
    BeforeAll {
        docker run --detach --interactive --tty --name "$global:CONTAINERNAME" "$global:AGENT_IMAGE" "$global:CONTAINERSHELL"
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
    }

    It 'has java installed and in the path' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"if(`$null -eq (Get-Command java.exe -ErrorAction SilentlyContinue)) { exit -1 } else { exit 0 }`""
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
        $stdout.Trim() | Should -Match "AGENT_WORKDIR.*C:/Users/jenkins/Work"
    }

    It 'has user in the environment' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"Get-ChildItem env:`""
        $exitCode | Should -Be 0
        $stdout.Trim() | Should -Match "user.*jenkins"
    }

    It 'has git-lfs (and thus git) installed' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"`& git lfs version`""
        $exitCode | Should -Be 0
        $stdout.Trim() | Should -Match "git-lfs/${global:GITLFSVERSION}"
    }

    It 'does not include jenkins-agent.ps1 (inbound-agent)' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"if(Test-Path C:/ProgramData/Jenkins/jenkins-agent.ps1) { exit -1 } else { exit 0 }`""
        $exitCode | Should -Be 0
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
    }
}

Describe "[$global:AGENT_TYPE > $global:AGENT_IMAGE] check user account" {
    BeforeAll {
        docker run -d -it --name "$global:CONTAINERNAME" -P "$global:AGENT_IMAGE" "$global:CONTAINERSHELL"
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
    }

    It 'Password never expires' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"if((net user jenkins | Select-String -Pattern 'Password expires') -match 'Never') { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'Password not required' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"if((net user jenkins | Select-String -Pattern 'Password required') -match 'No') { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
    }
}

Describe "[$global:AGENT_TYPE > $global:AGENT_IMAGE] check user access to directories" {
    BeforeAll {
        docker run -d -it --name "$global:CONTAINERNAME" -P "$global:AGENT_IMAGE" "$global:CONTAINERSHELL"
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
    }

    It 'can write to HOME' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"New-Item -ItemType File -Path C:/Users/jenkins/a.txt | Out-Null ; if(Test-Path C:/Users/jenkins/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'can write to HOME/.jenkins' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"New-Item -ItemType File -Path C:/Users/jenkins/.jenkins/a.txt | Out-Null ; if(Test-Path C:/Users/jenkins/.jenkins/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'can write to HOME/Work' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"New-Item -ItemType File -Path C:/Users/jenkins/Work/a.txt | Out-Null ; if(Test-Path C:/Users/jenkins/Work/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
    }
}

$global:TEST_VERSION="4.0"
$global:TEST_USER="test-user"
$global:TEST_AGENT_WORKDIR="C:/test-user/something"

Describe "[$global:AGENT_TYPE > $global:AGENT_IMAGE] can be built with custom build arguments" {
    BeforeAll {
        Push-Location -StackName 'agent' -Path "$PSScriptRoot/.."

        $exitCode, $stdout, $stderr = Run-Program 'docker' "build --target agent --build-arg `"VERSION=${global:TEST_VERSION}`" --build-arg `"WINDOWS_VERSION_TAG=${global:WINDOWSVERSIONTAG}`" --build-arg `"TOOLS_WINDOWS_VERSION=${global:WINDOWSVERSIONFALLBACKTAG}`" --build-arg `"user=${global:TEST_USER}`" --build-arg `"AGENT_WORKDIR=${global:TEST_AGENT_WORKDIR}`" --tag ${global:AGENT_IMAGE} --file ./windows/${global:WINDOWSFLAVOR}/Dockerfile ."
        $exitCode | Should -Be 0

        $exitCode, $stdout, $stderr = Run-Program 'docker' "run -d -it --name $global:CONTAINERNAME -P $global:AGENT_IMAGE $global:CONTAINERSHELL"
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
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"New-Item -ItemType File -Path C:/Users/${TEST_USER}/a.txt | Out-Null ; if(Test-Path C:/Users/${TEST_USER}/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'can write to HOME/.jenkins' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"New-Item -ItemType File -Path C:/Users/${TEST_USER}/.jenkins/a.txt | Out-Null ; if(Test-Path C:/Users/${TEST_USER}/.jenkins/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'can write to HOME/Work' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"New-Item -ItemType File -Path ${TEST_AGENT_WORKDIR}/a.txt | Out-Null ; if(Test-Path ${TEST_AGENT_WORKDIR}/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'version in docker metadata' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "inspect --format=`"{{index .Config.Labels \`"org.opencontainers.image.version\`"}}`" $global:AGENT_IMAGE"
        $exitCode | Should -Be 0
        $stdout.Trim() | Should -Match $global:sTEST_VERSION
    }

    AfterAll {
        Pop-Location -StackName 'agent'
        Cleanup($global:CONTAINERNAME)
    }
}
