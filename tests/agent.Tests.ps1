Import-Module -DisableNameChecking -Force $PSScriptRoot/test_helpers.psm1

$FOLDER='8\windows\servercore-1809'
$JDK=8
$AGENT_IMAGE='jenkins-agent'
$AGENT_CONTAINER='pester-jenkins-agent'
$SHELL="powershell.exe"

$FLAVOR = Get-EnvOrDefault 'FLAVOR' ''

if([System.String]::IsNullOrWhiteSpace($FLAVOR)) {
    $FLAVOR = 'jdk8'
} elseif($FLAVOR -eq "jdk11") {
    $FOLDER = '11\windows\servercore-1809'
    $JDK=11
    $AGENT_IMAGE += ":jdk11"
    $AGENT_CONTAINER += "-jdk11"
} elseif($FLAVOR -eq "nanoserver") {
    $FOLDER = '8\windows\nanoserver-1809'
    $AGENT_IMAGE += ":nanoserver-1809"
    $AGENT_CONTAINER += "-nanoserver"
    $SHELL="pwsh.exe"
} elseif($FLAVOR -eq "nanoserver-jdk11") {
    $FOLDER = '11\windows\nanoserver-1809'
    $JDK=11
    $AGENT_IMAGE += ":nanoserver-1809-jdk11"
    $AGENT_CONTAINER += "-nanoserver-jdk11"
    $SHELL="pwsh.exe"
}

Cleanup($AGENT_CONTAINER)

Describe "[$FLAVOR] build image" {
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

Describe "[$FLAVOR] correct image metadata" {
    It 'has correct volumes' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "inspect -f '{{.Config.Volumes}}' $AGENT_IMAGE"
        $stdout | Should -Match 'C:/Users/jenkins/.jenkins'
        $stdout | Should -Match 'C:/Users/jenkins/Work'
    }
}

Describe "[$FLAVOR] image has correct applications in the PATH" {
    BeforeAll {
        if($FOLDER.Contains('nanoserver')) {
            docker run -d -it --name "$AGENT_CONTAINER" -P "$AGENT_IMAGE" pwsh
        } else {
            docker run -d -it --name "$AGENT_CONTAINER" -P "$AGENT_IMAGE" powershell
        }
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
        $stdout | Should -Match "AGENT_WORKDIR.*C:/Users/jenkins/Work"
    }

    AfterAll {
        Cleanup($AGENT_CONTAINER)
    }
}

Describe "[$FLAVOR] check user access to directories" {
    BeforeAll {
        if($FOLDER.Contains('nanoserver')) {
            docker run -d -it --name "$AGENT_CONTAINER" -P "$AGENT_IMAGE" pwsh
        } else {
            docker run -d -it --name "$AGENT_CONTAINER" -P "$AGENT_IMAGE" powershell
        }
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

$TEST_VERSION="3.36"
$TEST_USER="test-user"
$TEST_AGENT_WORKDIR="C:/test-user/something"

Describe "[$FLAVOR] use build args correctly" {
    BeforeAll {
        Push-Location -StackName 'agent' -Path "$PSScriptRoot/.."

        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "build --build-arg `"VERSION=${TEST_VERSION}`" --build-arg `"user=${TEST_USER}`" --build-arg `"AGENT_WORKDIR=${TEST_AGENT_WORKDIR}`" -t ${AGENT_IMAGE} ${FOLDER}"
        $exitCode | Should -Be 0

        if($FOLDER.Contains('nanoserver')) {
            docker run -d -it --name "$AGENT_CONTAINER" -P "$AGENT_IMAGE" pwsh
        } else {
            docker run -d -it --name "$AGENT_CONTAINER" -P "$AGENT_IMAGE" powershell
        }
        Is-AgentContainerRunning $AGENT_CONTAINER
    }

    It 'has the correct version of remoting' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $AGENT_CONTAINER $SHELL -C `"`$version = java -cp C:/ProgramData/Jenkins/agent.jar hudson.remoting.jnlp.Main -version ; Write-Host `$version`""
        $exitCode | Should -Be 0
        $stdout | Should -Match $TEST_VERSION
    }

    It 'has correct user' {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "exec $AGENT_CONTAINER $SHELL -C `"(Get-ChildItem env:\ | Where-Object { `$_.Name -eq 'USERNAME' }).Value`""
        $exitCode | Should -Be 0
        $stdout | Should -Match $TEST_USER
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
