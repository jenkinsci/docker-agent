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

Describe "[$global:IMAGE_NAME] custom build args" {
    BeforeAll {
        Push-Location -StackName 'agent' -Path "$PSScriptRoot/.."
        # Old version used to test overriding the build arguments.
        # This old version must have the same tag suffixes as the current windows images (`-jdk17-nanoserver` etc.), and the same Windows version (2019, 2022, etc.)
        $TEST_VERSION = '3206.vb_15dcf73f6a_9'
        $customImageName = "custom-${global:IMAGE_NAME}"
    }

    It 'builds image with arguments' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "build --build-arg `"VERSION=${TEST_VERSION}`" --build-arg `"JAVA_VERSION=${global:JAVA_VERSION}`" --build-arg `"JAVA_HOME=C:\openjdk-${global:JAVAMAJORVERSION}`" --build-arg `"WINDOWS_VERSION_TAG=${global:WINDOWSVERSIONTAG}`" --build-arg WINDOWS_FLAVOR=${global:WINDOWSFLAVOR} --build-arg CONTAINER_SHELL=${global:CONTAINERSHELL} --tag=${customImageName} --file=./windows/${global:WINDOWSFLAVOR}/Dockerfile ."
        $exitCode | Should -Be 0

        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --name $global:CONTAINERNAME $customImageName -Cmd $global:CONTAINERSHELL"
        $exitCode | Should -Be 0
        Is-ContainerRunning "$global:CONTAINERNAME" | Should -BeTrue
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
