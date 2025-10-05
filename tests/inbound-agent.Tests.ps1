Import-Module -DisableNameChecking -Force $PSScriptRoot/test_helpers.psm1

$global:IMAGE_NAME = Get-EnvOrDefault 'IMAGE_NAME' '' # Ex: jenkins/inbound-agent:jdk17-nanoserver-1809
$global:VERSION = Get-EnvOrDefault 'VERSION' ''
$global:JAVA_VERSION = Get-EnvOrDefault 'JAVA_VERSION' ''

Write-Host "= TESTS: Preparing $global:IMAGE_NAME with Remoting $global:VERSION and Java $global:JAVA_VERSION"

$imageItems = $global:IMAGE_NAME.Split(':')
$GLOBAL:IMAGE_TAG = $imageItems[1]

$items = $global:IMAGE_TAG.Split('-')
# Remove the 'jdk' prefix (3 first characters)
$global:JAVAMAJORVERSION = $items[0].Remove(0,3)
$global:WINDOWSFLAVOR = $items[1]
$global:WINDOWSVERSIONTAG = $items[2]

$random = Get-Random
$global:CONTAINERNAME = 'pester-jenkins-inbound-agent_{0}_{1}' -f $global:IMAGE_TAG, $random
$global:JNLPNETWORKNAME = 'jnlp-{0}' -f $random
$global:NMAPCONTAINERNAME = 'nmap-{0}' -f $random
Write-Host "= TESTS: container name $global:CONTAINERNAME"
Write-Host "= TESTS: jnlp network name $global:JNLPNETWORKNAME"
Write-Host "= TESTS: nmap container name $global:NMAPCONTAINERNAME"

$global:CONTAINERSHELL = 'powershell.exe'
if ($global:WINDOWSFLAVOR -eq 'nanoserver') {
    $global:CONTAINERSHELL = 'pwsh.exe'
}

# # Uncomment to help debugging when working on this script
# Write-Host "= DEBUG: global vars"
# Get-Variable -Scope Global | ForEach-Object { Write-Host "$($_.Name) = $($_.Value)" }
# Write-Host "= DEBUG: env vars"
# Get-ChildItem Env: | ForEach-Object { Write-Host "$($_.Name) = $($_.Value)" }

Cleanup($global:CONTAINERNAME)
Cleanup($global:NMAPCONTAINERNAME)
CleanupNetwork($global:JNLPNETWORKNAME)

BuildNmapImage($global:WINDOWSVERSIONTAG)

# Describe "[$global:IMAGE_NAME] build image" {
#     It 'builds image' {
#         # if ($global:JAVAMAJORVERSION -eq 21) {
#         #     # Force an error on one of the JDK version for testing purpose
#         #     $global:JAVAMAJORVERSION | Should -Be 20
#         # }
#         $exitCode, $stdout, $stderr = Run-Program 'docker' "build --quiet --build-arg `"VERSION=${global:VERSION}`" --build-arg `"JAVA_VERSION=${global:JAVA_VERSION}`" --build-arg `"JAVA_HOME=C:\openjdk-${global:JAVAMAJORVERSION}`" --build-arg `"WINDOWS_VERSION_TAG=${global:WINDOWSVERSIONTAG}`" --tag=${global:IMAGE_TAG} --file ./windows/${global:WINDOWSFLAVOR}/Dockerfile ."
#         $exitCode | Should -Be 0
#     }
# }

# Describe "[$global:IMAGE_NAME] check default user account" {
#     BeforeAll {
#         docker run --detach --tty --name "$global:CONTAINERNAME" "$global:IMAGE_NAME" -Cmd "$global:CONTAINERSHELL"
#         $LASTEXITCODE | Should -Be 0
#         Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
#     }

#     It 'has a password that never expires' {
#         $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"if ((net user jenkins | Select-String -Pattern 'Password expires') -match 'Never') { exit 0 } else { net user jenkins ; exit -1 }`""
#         $exitCode | Should -Be 0
#     }

#     It 'has password policy of "not required"' {
#         $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"if ((net user jenkins | Select-String -Pattern 'Password required') -match 'No') { exit 0 } else { net user jenkins ; exit -1 }`""
#         $exitCode | Should -Be 0
#     }

#     AfterAll {
#         Cleanup($global:CONTAINERNAME)
#     }
# }

# Describe "[$global:IMAGE_NAME] image has jenkins-agent.ps1 in the correct location" {
#     BeforeAll {
#         docker run --detach --tty --name "$global:CONTAINERNAME" "$global:IMAGE_NAME" -Cmd "$global:CONTAINERSHELL"
#         $LASTEXITCODE | Should -Be 0
#         Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
#     }

#     It 'has jenkins-agent.ps1 in C:/ProgramData/Jenkins' {
#         $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"if (Test-Path 'C:/ProgramData/Jenkins/jenkins-agent.ps1') { exit 0 } else { exit 1 }`""
#         $exitCode | Should -Be 0
#     }

#     AfterAll {
#         Cleanup($global:CONTAINERNAME)
#     }
# }

# Describe "[$global:IMAGE_NAME] image starts jenkins-agent.ps1 correctly (slow test)" {
#     It 'connects to the nmap container' {
#         $exitCode, $stdout, $stderr = Run-Program 'docker' "network create --driver nat $global:JNLPNETWORKNAME"
#         # Launch the netcat utility, listening at port 5000 for 30 sec
#         # bats will capture the output from netcat and compare the first line
#         # of the header of the first HTTP request with the expected one
#         $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --name $global:NMAPCONTAINERNAME --network=$global:JNLPNETWORKNAME nmap:latest ncat.exe -w 30 -l 5000"
#         $exitCode | Should -Be 0
#         Is-ContainerRunning $global:NMAPCONTAINERNAME | Should -BeTrue

#         # get the ip address of the nmap container
#         $exitCode, $stdout, $stderr = Run-Program 'docker' "inspect --format `"{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}`" $global:NMAPCONTAINERNAME"
#         $exitCode | Should -Be 0
#         $nmap_ip = $stdout.Trim()

#         # run Jenkins agent which tries to connect to the nmap container at port 5000
#         $secret = "aaa"
#         $name = "bbb"
#         $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --network=$global:JNLPNETWORKNAME --name $global:CONTAINERNAME $global:IMAGE_NAME -Url http://${nmap_ip}:5000 $secret $name"
#         $exitCode | Should -Be 0
#         Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue

#         $exitCode, $stdout, $stderr = Run-Program 'docker' "wait $global:NMAPCONTAINERNAME"
#         $exitCode, $stdout, $stderr = Run-Program 'docker' "logs $global:NMAPCONTAINERNAME"
#         $exitCode | Should -Be 0
#         $stdout | Should -Match "GET /tcpSlaveAgentListener/ HTTP/1.1`r"
#     }

#     AfterAll {
#         Cleanup($global:CONTAINERNAME)
#         Cleanup($global:NMAPCONTAINERNAME)
#         CleanupNetwork($global:JNLPNETWORKNAME)
#     }
# }

Describe "[$global:IMAGE_NAME] custom build args" {
    BeforeAll {
        Push-Location -StackName 'agent' -Path "$PSScriptRoot/.."
        # Old version used to test overriding the build arguments.
        # This old version must have the same tag suffixes as the current windows images (`-jdk17-nanoserver` etc.), and the same Windows version (2019, 2022, etc.)
        $TEST_VERSION = '3206.vb_15dcf73f6a_9'
        $customImageName = "custom-${global:IMAGE_NAME}"
    }

    It 'builds image with arguments' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "build --quiet --build-arg `"VERSION=${TEST_VERSION}`" --build-arg `"JAVA_VERSION=${global:JAVA_VERSION}`" --build-arg `"JAVA_HOME=C:\openjdk-${global:JAVAMAJORVERSION}`" --build-arg `"WINDOWS_VERSION_TAG=${global:WINDOWSVERSIONTAG}`" --build-arg WINDOWS_FLAVOR=${global:WINDOWSFLAVOR} --build-arg CONTAINER_SHELL=${global:CONTAINERSHELL} --tag=${customImageName} --file=./windows/${global:WINDOWSFLAVOR}/Dockerfile ."
        $exitCode | Should -Be 0

        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --name $global:CONTAINERNAME $customImageName -Cmd $global:CONTAINERSHELL"
        $exitCode | Should -Be 0
        Is-ContainerRunning "$global:CONTAINERNAME" | Should -BeTrue
    }

    It 'has java in the path with the correct major version' {
        # try {
        #     Write-Host '[DEBUG] env:'
        #     docker exec $global:CONTAINERNAME $global:CONTAINERSHELL -c 'Get-ChildItem Env: | ForEach-Object { Write-Host "$($_.Name) = $($_.Value)" }'
        # # KO
        # $ErrorActionPreference = 'Continue'
        # Write-Host '[DEBUG] java -version:'
        # Write-Host (docker exec $global:CONTAINERNAME java -version)
        # Write-Host '[DEBUG] end java -version'
        # $ErrorActionPreference = 'Stop'

        #     Write-Host '[DEBUG] pwsh -c "java -version":'
        #     docker exec $global:CONTAINERNAME $global:CONTAINERSHELL -c "java -version"
        # } catch {}
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -c `"Invoke-Expression 'java -version'`""
        $exitCode | Should -Be 0
        $stdout | Should -Match $global:JAVAMAJORVERSION
    }

    It 'has the correct agent.jar version' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -c `"java -jar C:/ProgramData/Jenkins/agent.jar -version`""
        $exitCode | Should -Be 0
        $stdout | Should -Match $TEST_VERSION
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
        Pop-Location -StackName 'agent'
    }
}

# Describe "[$global:IMAGE_NAME] passing JVM options (slow test)" {
#     It 'connects to the nmap container' {
#         $exitCode, $stdout, $stderr = Run-Program 'docker' "network create --driver nat $global:JNLPNETWORKNAME"
#         # Launch the netcat utility, listening at port 5000 for 30 sec
#         # bats will capture the output from netcat and compare the first line
#         # of the header of the first HTTP request with the expected one
#         $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --name $global:NMAPCONTAINERNAME --network=$global:JNLPNETWORKNAME nmap:latest ncat.exe -w 30 -l 5000"
#         $exitCode | Should -Be 0
#         Is-ContainerRunning $global:NMAPCONTAINERNAME | Should -BeTrue

#         # get the ip address of the nmap container
#         $exitCode, $stdout, $stderr = Run-Program 'docker' "inspect --format `"{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}`" $global:NMAPCONTAINERNAME"
#         $exitCode | Should -Be 0
#         $nmap_ip = $stdout.Trim()

#         # run Jenkins agent which tries to connect to the nmap container at port 5000
#         $secret = 'aaa'
#         $name = 'bbb'
#         $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --network=$global:JNLPNETWORKNAME --name $global:CONTAINERNAME $global:IMAGE_NAME -Url http://${nmap_ip}:5000 -JenkinsJavaOpts `"--show-version`" $secret $name"
#         $exitCode | Should -Be 0
#         Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
#         Start-Sleep -Seconds 20
#         $exitCode, $stdout, $stderr = Run-Program 'docker' "logs $global:CONTAINERNAME"
#         $exitCode | Should -Be 0
#     }

#     AfterAll {
#         Cleanup($global:CONTAINERNAME)
#         Cleanup($global:NMAPCONTAINERNAME)
#         CleanupNetwork($global:JNLPNETWORKNAME)
#     }
# }
