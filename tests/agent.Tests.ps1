Import-Module -DisableNameChecking -Force $PSScriptRoot/test_helpers.psm1

$AGENT_IMAGE='jenkins-jnlp-agent'
$AGENT_CONTAINER='pester-jenkins-jnlp-agent'
$SHELL="powershell.exe"

$FOLDER = Get-EnvOrDefault 'FOLDER' ''
$VERSION = Get-EnvOrDefault 'VERSION' '4.3-1'

$REAL_FOLDER=Resolve-Path -Path "$PSScriptRoot/../${FOLDER}"

if(($FOLDER -match '^(?<jdk>[0-9]+)[\\/](?<flavor>.+)$') -and (Test-Path $REAL_FOLDER)) {
    $JDK = $Matches['jdk']
    $FLAVOR = $Matches['flavor']
} else {
    Write-Error "Wrong folder format or folder does not exist: $FOLDER"
    exit 1
}

if($FLAVOR -match "nanoserver") {
    $AGENT_IMAGE += "-nanoserver"
    $AGENT_CONTAINER += "-nanoserver-1809"
    $SHELL = "pwsh.exe"
}

if($JDK -eq "11") {
    $AGENT_IMAGE += ":jdk11"
    $AGENT_CONTAINER += "-jdk11"
} else {
    $AGENT_IMAGE += ":latest"
}

Cleanup($AGENT_CONTAINER)

Describe "[$JDK $FLAVOR] build image" {
    BeforeEach {
      Push-Location -StackName 'agent' -Path "$PSScriptRoot/.."
    }

    It 'builds image' {
      $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "build -t $AGENT_IMAGE $FOLDER"
      $exitCode | Should -Be 0
    }

    AfterEach {
      Pop-Location -StackName 'agent'
    }
}

Describe "[$JDK $FLAVOR] correct image metadata" {
    It 'has correct volumes' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "inspect -f '{{.Config.Volumes}}' $AGENT_IMAGE"
        $stdout = $stdout.Trim()
        $stdout | Should -Match 'C:/Users/jenkins/.jenkins'
        $stdout | Should -Match 'C:/Users/jenkins/Work'
    }
}

Describe "[$JDK $FLAVOR] image has correct applications in the PATH" {
    BeforeAll {
        docker run -d -it --name "$AGENT_CONTAINER" -P "$AGENT_IMAGE" "$SHELL"
        Is-AgentContainerRunning $AGENT_CONTAINER
    }

    It 'has java installed and in the path' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $AGENT_CONTAINER $SHELL -C `"if(`$null -eq (Get-Command java.exe -ErrorAction SilentlyContinue)) { exit -1 } else { exit 0 }`""
        $exitCode | Should -Be 0

        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $AGENT_CONTAINER $SHELL -C `"`$version = java -version 2>&1 ; Write-Host `$version`""
        if($JDK -eq 8) {
            $r = [regex] "^openjdk version `"(?<major>\d+)\.(?<minor>\d+)\.(?<build>\d+).*`""
            $m = $r.Match($stdout)
            $m | Should -Not -Be $null
            $m.Groups['minor'].ToString() | Should -Be "$JDK"
        } else {
            $r = [regex] "^openjdk version `"(?<major>\d+)"
            $m = $r.Match($stdout)
            $m | Should -Not -Be $null
            $m.Groups['major'].ToString() | Should -Be "$JDK"
        }
    }

    It 'has AGENT_WORKDIR in the envrionment' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $AGENT_CONTAINER $SHELL -C `"Get-ChildItem env:`""
        $exitCode | Should -Be 0
        $stdout.Trim() | Should -Match "AGENT_WORKDIR.*C:/Users/jenkins/Work"
    }

    AfterAll {
        Cleanup($AGENT_CONTAINER)
    }
}

Describe "[$JDK $FLAVOR] check user access to directories" {
    BeforeAll {
        docker run -d -it --name "$AGENT_CONTAINER" -P "$AGENT_IMAGE" "$SHELL"
        Is-AgentContainerRunning $AGENT_CONTAINER
    }

    It 'can write to HOME' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $AGENT_CONTAINER $SHELL -C `"New-Item -ItemType File -Path C:/Users/jenkins/a.txt | Out-Null ; if(Test-Path C:/Users/jenkins/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'can write to HOME/.jenkins' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $AGENT_CONTAINER $SHELL -C `"New-Item -ItemType File -Path C:/Users/jenkins/.jenkins/a.txt | Out-Null ; if(Test-Path C:/Users/jenkins/.jenkins/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'can write to HOME/Work' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $AGENT_CONTAINER $SHELL -C `"New-Item -ItemType File -Path C:/Users/jenkins/Work/a.txt | Out-Null ; if(Test-Path C:/Users/jenkins/Work/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    AfterAll {
        Cleanup($AGENT_CONTAINER)
    }
}

$TEST_VERSION="4.0"
$TEST_USER="test-user"
$TEST_AGENT_WORKDIR="C:/test-user/something"

Describe "[$JDK $FLAVOR] use build args correctly" {
    BeforeAll {
        Push-Location -StackName 'agent' -Path "$PSScriptRoot/.."

        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "build --build-arg `"VERSION=${TEST_VERSION}`" --build-arg `"user=${TEST_USER}`" --build-arg `"AGENT_WORKDIR=${TEST_AGENT_WORKDIR}`" -t ${AGENT_IMAGE} ${FOLDER}"
        $exitCode | Should -Be 0

        docker run -d -it --name "$AGENT_CONTAINER" -P "$AGENT_IMAGE" "$SHELL"
        Is-AgentContainerRunning $AGENT_CONTAINER
    }

    It 'has the correct version of remoting' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $AGENT_CONTAINER $SHELL -C `"`$version = java -cp C:/ProgramData/Jenkins/agent.jar hudson.remoting.jnlp.Main -version ; Write-Host `$version`""
        $exitCode | Should -Be 0
        $stdout.Trim() | Should -Match $TEST_VERSION
    }

    It 'has correct user' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $AGENT_CONTAINER $SHELL -C `"(Get-ChildItem env:\ | Where-Object { `$_.Name -eq 'USERNAME' }).Value`""
        $exitCode | Should -Be 0
        $stdout.Trim() | Should -Match $TEST_USER
    }

    It 'has correct AGENT_WORKDIR' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $AGENT_CONTAINER $SHELL -C `"Get-ChildItem env:`""
        $exitCode | Should -Be 0
        $stdout | Should -Match "AGENT_WORKDIR.*${TEST_AGENT_WORKDIR}"
    }

    It 'can write to HOME' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $AGENT_CONTAINER $SHELL -C `"New-Item -ItemType File -Path C:/Users/${TEST_USER}/a.txt | Out-Null ; if(Test-Path C:/Users/${TEST_USER}/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'can write to HOME/.jenkins' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $AGENT_CONTAINER $SHELL -C `"New-Item -ItemType File -Path C:/Users/${TEST_USER}/.jenkins/a.txt | Out-Null ; if(Test-Path C:/Users/${TEST_USER}/.jenkins/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'can write to HOME/Work' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $AGENT_CONTAINER $SHELL -C `"New-Item -ItemType File -Path ${TEST_AGENT_WORKDIR}/a.txt | Out-Null ; if(Test-Path ${TEST_AGENT_WORKDIR}/a.txt) { exit 0 } else { exit -1 }`""
        $exitCode | Should -Be 0
    }

    AfterAll {
        Pop-Location -StackName 'agent'
        Cleanup($AGENT_CONTAINER)
    }
}
