# Inspired by https://github.com/AvaloniaUI/avalonia-dotnet-templates/blob/main/tests/build-test.ps1
# Enable common parameters e.g. -Verbose
[CmdletBinding()]
param()

Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"

# Taken from psake https://github.com/psake/psake
<#
.SYNOPSIS
  This is a helper function that runs a scriptblock and checks the PS variable $lastexitcode
  to see if an error occcured. If an error is detected then an exception is thrown.
  This function allows you to run command-line programs without having to
  explicitly check the $lastexitcode variable.
.EXAMPLE
  exec { svn info $repository_trunk } "Error executing SVN. Please verify SVN command-line client is installed"
#>
function Exec
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)][scriptblock]$cmd,
        [Parameter(Position=1,Mandatory=0)][string]$errorMessage = ("Error executing command {0}" -f $cmd)
    )    

    # Convert the ScriptBlock to a string and expand the variables
    $expandedCmdString = $ExecutionContext.InvokeCommand.ExpandString($cmd.ToString())    
    Write-Verbose "Executing command: $expandedCmdString"

    Invoke-Command -ScriptBlock $cmd
    
    if ($lastexitcode -ne 0) {
        throw ("Exec: " + $errorMessage)
    }
}

function Test-Template {
    param (
        [Parameter(Position=0,Mandatory=1)][string]$template,
        [Parameter(Position=1,Mandatory=1)][string]$name,
        [Parameter(Position=2,Mandatory=1)][string]$lang,
        [Parameter(Position=3,Mandatory=1)][string]$parameterName,
        [Parameter(Position=4,Mandatory=1)][string]$value,
        [Parameter(Position=5,Mandatory=0)][string]$bl
    )

    $folderName = $name + $parameterName + $value
    
    # Remove dots and - from folderName because in sln it will cause errors when building project
    $folderName = $folderName -replace "[.-]"
    
    # Create the project
    Exec { dotnet new $template -o output//$lang/$folderName -$parameterName $value -lang $lang }

    # Build
    Exec { dotnet build output/$lang/$folderName -bl:$bl }
    Exec { dotnet test output/$lang/$folderName -bl:$bl } # some templates might include unit tests
    Exec { dotnet publish -c Release -t:PublishContainer output/$lang/$folderName -bl:$bl }
}

function Create-And-Build {
    param (
        [Parameter(Position=0,Mandatory=1)][string]$template,
        [Parameter(Position=1,Mandatory=1)][string]$name,
        [Parameter(Position=2,Mandatory=1)][string]$lang,
        [Parameter(Position=3,Mandatory=1)][string]$parameterName,
        [Parameter(Position=4,Mandatory=1)][string]$value,
        [Parameter(Position=5,Mandatory=0)][string]$bl
    )
    
    $folderName = $name + $parameterName + $value
    
    # Remove dots and - from folderName because in sln it will cause errors when building project
    $folderName = $folderName -replace "[.-]"

    # Create the project
    Exec { dotnet new $template -o output/$lang/$folderName -$parameterName $value -lang $lang }

    # Build
    Exec { dotnet build output/$lang/$folderName -bl:$bl }
}

# Clear file system from possible previous runs
Write-Output "Clearing outputs from possible previous runs"
if (Test-Path "output" -ErrorAction SilentlyContinue) {
    Remove-Item -Recurse -Force "output"
}
$outDir = [IO.Path]::GetFullPath([IO.Path]::Combine($pwd, "..", "output"))
if (Test-Path $outDir -ErrorAction SilentlyContinue) {
    Remove-Item -Recurse -Force $outDir
}
$binLogDir = [IO.Path]::GetFullPath([IO.Path]::Combine($pwd, "..", "binlog"))
if (Test-Path $binLogDir -ErrorAction SilentlyContinue) {
    Remove-Item -Recurse -Force $binLogDir
}

# Use same log file for all executions
$binlog = [IO.Path]::GetFullPath([IO.Path]::Combine($pwd, "..", "binlog", "test.binlog"))

Create-And-Build "akka.console" "AkkaConsole" "C#" "f" "net9.0" $binlog
Create-And-Build "akka.console" "AkkaConsole" "C#" "f" "net8.0" $binlog

Create-And-Build "akka.console" "AkkaConsole" "F#" "f" "net9.0" $binlog
Create-And-Build "akka.console" "AkkaConsole" "F#" "f" "net8.0" $binlog

Create-And-Build "akka.streams" "AkkaStreams" "C#" "f" "net9.0" $binlog
Create-And-Build "akka.streams" "AkkaStreams" "C#" "f" "net8.0" $binlog

Test-Template "akka.cluster.webapi" "ClusterWebTemplate" "C#" "f" "net9.0" $binlog
Test-Template "akka.cluster.webapi" "ClusterWebTemplate" "C#" "f" "net8.0" $binlog

# Ignore errors when files are still used by another process