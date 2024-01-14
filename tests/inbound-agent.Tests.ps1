Import-Module -DisableNameChecking -Force $PSScriptRoot/test_helpers.psm1

$global:IMAGE_NAME = Get-EnvOrDefault 'IMAGE_NAME' ''
$global:VERSION = Get-EnvOrDefault 'VERSION' ''

$imageItems = $global:IMAGE_NAME.Split(":")
$GLOBAL:IMAGE_TAG = $imageItems[1]

$items = $global:IMAGE_TAG.Split("-")
# Remove the 'jdk' prefix (3 first characters)
$global:JAVAMAJORVERSION = $items[0].Remove(0,3)
$global:WINDOWSFLAVOR = $items[1]
$global:WINDOWSVERSIONTAG = $items[2]

# TODO: make this name unique for concurency
$global:CONTAINERNAME = 'pester-jenkins-inbound-agent-{0}' -f $global:IMAGE_TAG

$global:CONTAINERSHELL="powershell.exe"
if($global:WINDOWSFLAVOR -eq 'nanoserver') {
    $global:CONTAINERSHELL = "pwsh.exe"
}

# # Uncomment to help debugging when working on this script
# Write-Host "= DEBUG: global vars"
# Get-Variable -Scope Global | ForEach-Object { Write-Host "$($_.Name) = $($_.Value)" }
# Write-Host "= DEBUG: env vars"
# Get-ChildItem Env: | ForEach-Object { Write-Host "$($_.Name) = $($_.Value)" }

Cleanup($global:CONTAINERNAME)
Cleanup("nmap")
CleanupNetwork("jnlp-network")

BuildNcatImage($global:WINDOWSVERSIONTAG)

Describe "[$global:IMAGE_NAME] build image" {
    It 'builds image' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "build --build-arg VERSION=${global:VERSION} --build-arg `"WINDOWS_VERSION_TAG=${global:WINDOWSVERSIONTAG}`" --build-arg `"JAVA_VERSION=${global:JAVAMAJORVERSION}`" --build-arg `"JAVA_HOME=C:\openjdk-${global:JAVAMAJORVERSION}`" --tag=${global:IMAGE_TAG} --file ./windows/${global:WINDOWSFLAVOR}/Dockerfile ."
        $exitCode | Should -Be 0
    }
}

Describe "[$global:IMAGE_NAME] check default user account" {
    BeforeAll {
        docker run --detach --tty --name "$global:CONTAINERNAME" "$global:IMAGE_NAME" -Cmd "$global:CONTAINERSHELL"
        $LASTEXITCODE | Should -Be 0
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
    }

    It 'has a password that never expires' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"if((net user jenkins | Select-String -Pattern 'Password expires') -match 'Never') { exit 0 } else { net user jenkins ; exit -1 }`""
        $exitCode | Should -Be 0
    }

    It 'has password policy of "not required"' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"if((net user jenkins | Select-String -Pattern 'Password required') -match 'No') { exit 0 } else { net user jenkins ; exit -1 }`""
        $exitCode | Should -Be 0
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
    }
}

Describe "[$global:IMAGE_NAME] image has jenkins-agent.ps1 in the correct location" {
    BeforeAll {
        docker run --detach --tty --name "$global:CONTAINERNAME" "$global:IMAGE_NAME" -Cmd "$global:CONTAINERSHELL"
        $LASTEXITCODE | Should -Be 0
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
    }

    It 'has jenkins-agent.ps1 in C:/ProgramData/Jenkins' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"if(Test-Path 'C:/ProgramData/Jenkins/jenkins-agent.ps1') { exit 0 } else { exit 1 }`""
        $exitCode | Should -Be 0
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
    }
}

Describe "[$global:IMAGE_NAME] image starts jenkins-agent.ps1 correctly (slow test)" {
    It 'connects to the nmap container' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "network create --driver nat jnlp-network"
        # Launch the netcat utility, listening at port 5000 for 30 sec
        # bats will capture the output from netcat and compare the first line
        # of the header of the first HTTP request with the expected one
        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --name nmap --network=jnlp-network nmap:latest ncat.exe -w 30 -l 5000"
        $exitCode | Should -Be 0
        Is-ContainerRunning "nmap" | Should -BeTrue

        # get the ip address of the nmap container
        $exitCode, $stdout, $stderr = Run-Program 'docker' "inspect --format `"{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}`" nmap"
        $exitCode | Should -Be 0
        $nmap_ip = $stdout.Trim()

        # run Jenkins agent which tries to connect to the nmap container at port 5000
        $secret = "aaa"
        $name = "bbb"
        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --network=jnlp-network --name $global:CONTAINERNAME $global:IMAGE_NAME -Url http://${nmap_ip}:5000 $secret $name"
        $exitCode | Should -Be 0
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue

        $exitCode, $stdout, $stderr = Run-Program 'docker' 'wait nmap'
        $exitCode, $stdout, $stderr = Run-Program 'docker' 'logs nmap'
        $exitCode | Should -Be 0
        $stdout | Should -Match "GET /tcpSlaveAgentListener/ HTTP/1.1`r"
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
        Cleanup("nmap")
        CleanupNetwork("jnlp-network")
    }
}

Describe "[$global:IMAGE_NAME] custom build args" {
    BeforeAll {
        Push-Location -StackName 'agent' -Path "$PSScriptRoot/.."
        # Old version used to test overriding the build arguments.
        # This old version must have the same tag suffixes as the current windows images (`-jdk17-nanoserver` etc.), and the same Windows version (2019, 2022, etc.)
        $TEST_VERSION = "3206.vb_15dcf73f6a_9"
        $customImageName = "custom-${global:IMAGE_NAME}"
    }

    It 'builds image with arguments' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "build --build-arg VERSION=${TEST_VERSION} --build-arg `"WINDOWS_VERSION_TAG=${global:WINDOWSVERSIONTAG}`" --build-arg `"JAVA_VERSION=${global:JAVAMAJORVERSION}`" --build-arg `"JAVA_HOME=C:\openjdk-${global:JAVAMAJORVERSION}`" --build-arg WINDOWS_FLAVOR=${global:WINDOWSFLAVOR} --build-arg CONTAINER_SHELL=${global:CONTAINERSHELL} --tag=${customImageName} --file=./windows/${global:WINDOWSFLAVOR}/Dockerfile ."
        $exitCode | Should -Be 0

        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --name $global:CONTAINERNAME $customImageName -Cmd $global:CONTAINERSHELL"
        $exitCode | Should -Be 0
        Is-ContainerRunning "$global:CONTAINERNAME" | Should -BeTrue
    }

    It "has the correct agent.jar version" {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -c `"java -jar C:/ProgramData/Jenkins/agent.jar -version`""
        $exitCode | Should -Be 0
        $stdout | Should -Match $TEST_VERSION
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
        Pop-Location -StackName 'agent'
    }
}

Describe "[$global:IMAGE_NAME] passing JVM options (slow test)" {
    It "shows the java version ${global:JAVAMAJORVERSION} with --show-version" {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "network create --driver nat jnlp-network"
        # Launch the netcat utility, listening at port 5000 for 30 sec
        # bats will capture the output from netcat and compare the first line
        # of the header of the first HTTP request with the expected one
        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --name nmap --network=jnlp-network nmap:latest ncat.exe -w 30 -l 5000"
        $exitCode | Should -Be 0
        Is-ContainerRunning "nmap" | Should -BeTrue

        # get the ip address of the nmap container
        $exitCode, $stdout, $stderr = Run-Program 'docker' "inspect --format `"{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}`" nmap"
        $exitCode | Should -Be 0
        $nmap_ip = $stdout.Trim()

        # run Jenkins agent which tries to connect to the nmap container at port 5000
        $secret = "aaa"
        $name = "bbb"
        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --network=jnlp-network --name $global:CONTAINERNAME $global:IMAGE_NAME -Url http://${nmap_ip}:5000 -JenkinsJavaOpts `"--show-version`" $secret $name"
        $exitCode | Should -Be 0
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
        Start-Sleep -Seconds 20
        $exitCode, $stdout, $stderr = Run-Program 'docker' "logs $global:CONTAINERNAME"
        $exitCode | Should -Be 0
        $stdout | Should -Match "OpenJDK Runtime Environment Temurin-${global:JAVAMAJORVERSION}"
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
        Cleanup("nmap")
        CleanupNetwork("jnlp-network")
    }
}
