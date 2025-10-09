Import-Module -DisableNameChecking -Force $PSScriptRoot/test_helpers.psm1

$global:IMAGE_NAME = Get-EnvOrDefault 'IMAGE_NAME' '' # Ex: jenkins/inbound-agent:jdk17-nanoserver-1809
$global:VERSION = Get-EnvOrDefault 'VERSION' ''
$global:JAVA_VERSION = Get-EnvOrDefault 'JAVA_VERSION' ''

Write-Host "==== TESTS: Preparing $global:IMAGE_NAME with Remoting $global:VERSION and Java $global:JAVA_VERSION"

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
Write-Host "==== TESTS: container name $global:CONTAINERNAME"

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

BuildNcatImage($global:WINDOWSVERSIONTAG)

Describe "[$global:IMAGE_NAME] image starts jenkins-agent.ps1 correctly (slow test)" {
    It 'connects to the nmap container' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "network create --driver nat $global:JNLPNETWORKNAME"
        # Launch the netcat utility, listening at port 5000 for 30 sec
        # bats will capture the output from netcat and compare the first line
        # of the header of the first HTTP request with the expected one
        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --name $global:NMAPCONTAINERNAME --network=$global:JNLPNETWORKNAME nmap:latest ncat.exe -w 30 -l 5000"
        $exitCode | Should -Be 0
        Is-ContainerRunning $global:NMAPCONTAINERNAME | Should -BeTrue

        # get the ip address of the nmap container
        $exitCode, $stdout, $stderr = Run-Program 'docker' "inspect --format `"{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}`" $global:NMAPCONTAINERNAME"
        $exitCode | Should -Be 0
        $nmap_ip = $stdout.Trim()

        # run Jenkins agent which tries to connect to the nmap container at port 5000
        $secret = "aaa"
        $name = "bbb"
        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --network=$global:JNLPNETWORKNAME --name $global:CONTAINERNAME $global:IMAGE_NAME -Url http://${nmap_ip}:5000 $secret $name"
        $exitCode | Should -Be 0
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue

        $exitCode, $stdout, $stderr = Run-Program 'docker' "wait $global:NMAPCONTAINERNAME"
        $exitCode, $stdout, $stderr = Run-Program 'docker' "logs $global:NMAPCONTAINERNAME"
        $exitCode | Should -Be 0
        $stdout | Should -Match "GET /tcpSlaveAgentListener/ HTTP/1.1`r"
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
        Cleanup($global:NMAPCONTAINERNAME)
        CleanupNetwork($global:JNLPNETWORKNAME)
    }
}
