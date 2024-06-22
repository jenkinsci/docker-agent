function Test-CommandExists($command) {
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    $res = $false
    try {
        if(Get-Command $command) { 
            $res = $true 
        }
    } catch {
        $res = $false 
    } finally {
        $ErrorActionPreference=$oldPreference
    }
    return $res
}

# check dependencies
if(-Not (Test-CommandExists docker)) {
    Write-Error "docker is not available"
}

function Get-EnvOrDefault($name, $def) {
    $entry = Get-ChildItem env: | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    if(($null -ne $entry) -and ![System.String]::IsNullOrWhiteSpace($entry.Value)) {
        return $entry.Value
    }
    return $def
}

function Retry-Command {
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ValueFromPipeline)] 
        [ValidateNotNullOrEmpty()]
        [scriptblock] $ScriptBlock,
        [int] $RetryCount = 3,
        [int] $Delay = 30,
        [string] $SuccessMessage = "Command executed successfuly!",
        [string] $FailureMessage = "Failed to execute the command"
        )

    process {
        $Attempt = 1
        $Flag = $true

        do {
            try {
                $PreviousPreference = $ErrorActionPreference
                $ErrorActionPreference = 'Stop'
                Invoke-Command -NoNewScope -ScriptBlock $ScriptBlock -OutVariable Result 4>&1
                $ErrorActionPreference = $PreviousPreference

                # flow control will execute the next line only if the command in the scriptblock executed without any errors
                # if an error is thrown, flow control will go to the 'catch' block
                Write-Verbose "$SuccessMessage `n"
                $Flag = $false
            }
            catch {
                if ($Attempt -gt $RetryCount) {
                    Write-Verbose "$FailureMessage! Total retry attempts: $RetryCount"
                    Write-Verbose "[Error Message] $($_.exception.message) `n"
                    $Flag = $false
                } else {
                    Write-Verbose "[$Attempt/$RetryCount] $FailureMessage. Retrying in $Delay seconds..."
                    Start-Sleep -Seconds $Delay
                    $Attempt = $Attempt + 1
                }
            }
        }
        While ($Flag)
    }
}

function Cleanup($name='') {
    if([System.String]::IsNullOrWhiteSpace($name)) {
        $name = Get-EnvOrDefault 'AGENT_IMAGE' ''
    }

    if(![System.String]::IsNullOrWhiteSpace($name)) {
        docker kill "$name" 2>&1 | Out-Null
        docker rm -fv "$name" 2>&1 | Out-Null
    }
}

function Is-ContainerRunning($container='') {
    if([System.String]::IsNullOrWhiteSpace($container)) {
        $container = Get-EnvOrDefault 'AGENT_CONTAINER' ''
    }

    Start-Sleep -Seconds 5
    Retry-Command -RetryCount 10 -Delay 3 -ScriptBlock { 
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "inspect -f `"{{.State.Running}}`" $container"
        if(($exitCode -ne 0) -or (-not $stdout.Contains('true')) ) {
            throw('Exit code incorrect, or invalid value for running state')
        }
        return $true
    }
}

function Run-Program($cmd, $params) {
    if(-not $quiet) {
        Write-Host "cmd & params: $cmd $params"
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.WorkingDirectory = (Get-Location)
    $psi.FileName = $cmd
    $psi.Arguments = $params
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    if(($env:TESTS_DEBUG -eq 'debug') -or ($env:TESTS_DEBUG -eq 'verbose')) {
        Write-Host -ForegroundColor DarkBlue "[cmd] $cmd $params"
        if ($env:TESTS_DEBUG -eq 'verbose') {
            Write-Host -ForegroundColor DarkGray "[stdout] $stdout"
        }
        if($proc.ExitCode -ne 0){
            Write-Host -ForegroundColor DarkRed "[stderr] $stderr"
        }
    }

    return $proc.ExitCode, $stdout, $stderr
}

function BuildNcatImage($windowsVersionTag) {
    Write-Host "Building nmap image (Windows version '${windowsVersionTag}') for testing"
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "inspect --type=image nmap" $true
    if($exitCode -ne 0) {
        Push-Location -StackName 'agent' -Path "$PSScriptRoot/.."
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "build -t nmap --build-arg `"WINDOWS_VERSION_TAG=${windowsVersionTag}`" -f ./tests/netcat-helper/Dockerfile-windows ./tests/netcat-helper"
        $exitCode | Should -Be 0
        Pop-Location -StackName 'agent'
    }
}

function CleanupNetwork($name) {
    docker network rm $name 2>&1 | Out-Null
}
