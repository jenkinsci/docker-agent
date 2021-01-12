Import-Module -DisableNameChecking -Force $PSScriptRoot/test_helpers.psm1

$global:AGENT_IMAGE='jenkins-jnlp-agent'
$global:AGENT_CONTAINER='pester-jenkins-jnlp-agent'
$global:SHELL="powershell.exe"

$global:FOLDER = Get-EnvOrDefault 'FOLDER' ''
$global:VERSION = Get-EnvOrDefault 'VERSION' '4.6-1'

$global:REAL_FOLDER=Resolve-Path -Path "$PSScriptRoot/../${global:FOLDER}"

if(($global:FOLDER -match '^(\.[\\/])?(?<jdk>[0-9]+)[\\/]windows[\\/](?<flavor>.+)$') -and (Test-Path $global:REAL_FOLDER)) {
    $global:JDK = $Matches['jdk']
    $global:FLAVOR = $Matches['flavor']
} else {
    Write-Error "Wrong folder format or folder does not exist: $global:FOLDER"
    exit 1
}

if($global:FLAVOR -match "nanoserver-(?<version>\d*)") {
    $global:AGENT_IMAGE += "-nanoserver"
    $global:AGENT_CONTAINER += "-nanoserver-$($Matches['version'])"
    $global:SHELL = "pwsh.exe"
}

if($global:JDK -eq "11") {
    $global:AGENT_IMAGE += ":jdk11"
    $global:AGENT_CONTAINER += "-jdk11"
} else {
    $global:AGENT_IMAGE += ":latest"
}

Cleanup($global:AGENT_CONTAINER)

Describe "[$global:JDK $global:FLAVOR] build image" {
    BeforeEach {
      Push-Location -StackName 'agent' -Path "$PSScriptRoot/.."
    }

    It 'builds image' {
      $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "build -t $global:AGENT_IMAGE $global:FOLDER"
      $exitCode | Should -Be 0
    }

    AfterEach {
      Pop-Location -StackName 'agent'
    }
}

Describe "[$global:JDK $global:FLAVOR] correct image metadata" {
    It 'has correct volumes' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "inspect -f '{{.Config.Volumes}}' $global:AGENT_IMAGE"
        $stdout = $stdout.Trim()
        $stdout | Should -Match 'C:/Users/jenkins/.jenkins'
        $stdout | Should -Match 'C:/Users/jenkins/Work'
    }
}

Describe "[$global:JDK $global:FLAVOR] image has correct applications in the PATH" {
    BeforeAll {
        docker run -d -it --name "$global:AGENT_CONTAINER" -P "$global:AGENT_IMAGE" "$global:SHELL"
        Is-AgentContainerRunning $global:AGENT_CONTAINER
    }

    It 'has java installed and in the path' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -C `"if(`$null -eq (Get-Command java.exe -ErrorAction SilentlyContinue)) { exit -1 } else { exit 0 }`""
        $exitCode | Should -Be 0

        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -C `"`$global:VERSION = java -version 2>&1 ; Write-Host `$global:VERSION`""
        if($global:JDK -eq 8) {
            $r = [regex] "^openjdk version `"(?<major>\d+)\.(?<minor>\d+)\.(?<build>\d+).*`""
            $m = $r.Match($stdout)
            $m | Should -Not -Be $null
            $m.Groups['minor'].ToString() | Should -Be "$global:JDK"
        } else {
            $r = [regex] "^openjdk version `"(?<major>\d+)"
            $m = $r.Match($stdout)
            $m | Should -Not -Be $null
            $m.Groups['major'].ToString() | Should -Be "$global:JDK"
        }
    }

    It 'has AGENT_WORKDIR in the envrionment' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -C `"Get-ChildItem env:`""
        $exitCode | Should -Be 0
        $stdout.Trim() | Should -Match "AGENT_WORKDIR.*C:/Users/jenkins/Work"
    }

    AfterAll {
        Cleanup($global:AGENT_CONTAINER)
    }
}

Describe "[$global:JDK $global:FLAVOR] check user account" {
    BeforeAll {
        docker run -d -it --name "$global:AGENT_CONTAINER" -P "$global:AGENT_IMAGE" "$global:SHELL"
        Is-AgentContainerRunning $global:AGENT_CONTAINER
    }

    It 'Password never expires' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -C `"if((net user jenkins | Select-String -Pattern 'Password expires') -match 'Never') { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'Password not required' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -C `"if((net user jenkins | Select-String -Pattern 'Password required') -match 'No') { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    AfterAll {
        Cleanup($global:AGENT_CONTAINER)
    }
}

Describe "[$global:JDK $global:FLAVOR] check user access to directories" {
    BeforeAll {
        docker run -d -it --name "$global:AGENT_CONTAINER" -P "$global:AGENT_IMAGE" "$global:SHELL"
        Is-AgentContainerRunning $global:AGENT_CONTAINER
    }

    It 'can write to HOME' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -C `"New-Item -ItemType File -Path C:/Users/jenkins/a.txt | Out-Null ; if(Test-Path C:/Users/jenkins/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'can write to HOME/.jenkins' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -C `"New-Item -ItemType File -Path C:/Users/jenkins/.jenkins/a.txt | Out-Null ; if(Test-Path C:/Users/jenkins/.jenkins/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'can write to HOME/Work' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -C `"New-Item -ItemType File -Path C:/Users/jenkins/Work/a.txt | Out-Null ; if(Test-Path C:/Users/jenkins/Work/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    AfterAll {
        Cleanup($global:AGENT_CONTAINER)
    }
}

$global:TEST_VERSION="4.0"
$global:TEST_USER="test-user"
$global:TEST_AGENT_WORKDIR="C:/test-user/something"

Describe "[$global:JDK $global:FLAVOR] use build args correctly" {
    BeforeAll {
        Push-Location -StackName 'agent' -Path "$PSScriptRoot/.."

        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "build --build-arg `"VERSION=${global:TEST_VERSION}`" --build-arg `"user=${global:TEST_USER}`" --build-arg `"AGENT_WORKDIR=${global:TEST_AGENT_WORKDIR}`" -t ${global:AGENT_IMAGE} ${global:FOLDER}"
        $exitCode | Should -Be 0

        docker run -d -it --name "$global:AGENT_CONTAINER" -P "$global:AGENT_IMAGE" "$global:SHELL"
        Is-AgentContainerRunning $global:AGENT_CONTAINER
    }

    It 'has the correct version of remoting' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -C `"`$global:VERSION = java -cp C:/ProgramData/Jenkins/agent.jar hudson.remoting.jnlp.Main -version ; Write-Host `$global:VERSION`""
        $exitCode | Should -Be 0
        $stdout.Trim() | Should -Match $TEST_VERSION
    }

    It 'has correct user' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -C `"(Get-ChildItem env:\ | Where-Object { `$_.Name -eq 'USERNAME' }).Value`""
        $exitCode | Should -Be 0
        $stdout.Trim() | Should -Match $TEST_USER
    }

    It 'has correct AGENT_WORKDIR' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -C `"Get-ChildItem env:`""
        $exitCode | Should -Be 0
        $stdout | Should -Match "AGENT_WORKDIR.*${TEST_AGENT_WORKDIR}"
    }

    It 'can write to HOME' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -C `"New-Item -ItemType File -Path C:/Users/${TEST_USER}/a.txt | Out-Null ; if(Test-Path C:/Users/${TEST_USER}/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'can write to HOME/.jenkins' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -C `"New-Item -ItemType File -Path C:/Users/${TEST_USER}/.jenkins/a.txt | Out-Null ; if(Test-Path C:/Users/${TEST_USER}/.jenkins/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'can write to HOME/Work' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $global:AGENT_CONTAINER $global:SHELL -C `"New-Item -ItemType File -Path ${TEST_AGENT_WORKDIR}/a.txt | Out-Null ; if(Test-Path ${TEST_AGENT_WORKDIR}/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    AfterAll {
        Pop-Location -StackName 'agent'
        Cleanup($global:AGENT_CONTAINER)
    }
}
