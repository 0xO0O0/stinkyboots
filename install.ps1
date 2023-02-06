# If unable to execute due to policy rules, run
# Set-ExecutionPolicy RemoteSigned -Scope CurrentUser.

# Exit immediately if a PowerShell Cmdlet encounters an error.
$ErrorActionPreference = 'Stop'

# Show CLI help information.
Function Usage() {
    Write-Output @'
Bootware Installer
Installer script for Bootware

USAGE:
    bootware-installer [OPTIONS]

OPTIONS:
    -h, --help                  Print help information
    -u, --user                  Install bootware for current user
    -v, --version <VERSION>     Version of Bootware to install
'@
}

Function CheckEnvironment($Target) {
    If (($PSVersionTable.PSVersion.Major) -LT 5) {
        Write-Output @'
PowerShell 5 or later is required to run Bootware.
Upgrade PowerShell: https://docs.microsoft.com/powershell/scripting/windows-powershell/install/installing-windows-powershell
'@
        Exit 1
    }

    $AllowedExecutionPolicy = @('Unrestricted', 'RemoteSigned', 'ByPass')
    If ((Get-ExecutionPolicy).ToString() -NotIn $AllowedExecutionPolicy) {
        Write-Output @"
PowerShell requires an execution policy [$($AllowedExecutionPolicy -Join ', ')] to run Bootware.
To set the execution policy to the recommended 'RemoteSigned' run:
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
"@
        Exit 1
    }

    If ($Target -Eq 'Machine' -And !(IsAdministrator)) {
        Write-Output @"
System level installation requires an administrator console.
Run this script from an administrator console or execute with the '--user' flag.
"@
        Exit 1
    }
}

# Download file to destination efficiently.
#
# Required as a seperate function, since the default progress bar updates every
# byte, making downloads slow. For more information, visit
# https://stackoverflow.com/a/43477248.
Function DownloadFile {
    Param(
        [String] $SrcURL,
        [String] $DstFile
    )

    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -UseBasicParsing -Uri "$SrcURL" -OutFile "$DstFile"
}

# Print error message and exit script with usage error code.
Function ErrorUsage($Message) {
    Throw "Error: $Message"
    Exit 2
}

# Install completion script for Bootware.
Function InstallCompletion($Version) {
    $PowerShellURL = "https://raw.githubusercontent.com/0xO0O0/stinkyboots/$Version/completions/BootwareCompletion.psm1"

    $Paths = @(
        "$HOME/Documents/PowerShell/Modules/BootwareCompletion"
        "$HOME/Documents/WindowsPowerShell/Modules/BootwareCompletion"
    )
    ForEach ($Path in $Paths) {
        New-Item -Force -ItemType Directory -Path "$Path" | Out-Null
        DownloadFile "$PowerShellURL" "$Path/BootwareCompletion.psm1"
    }
}


# Check if script is run from an admin console.
Function IsAdministrator {
    Return ([Security.Principal.WindowsPrincipal]`
            [Security.Principal.WindowsIdentity]::GetCurrent()`
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Print log message to stdout if logging is enabled.
Function Log($Message) {
    If (!"$Env:BOOTWARE_NOLOG") {
        Write-Output "$Message"
    }
}

# Script entrypoint.
Function Main() {
    $ArgIdx = 0
    $Target = 'Machine'
    $Version = 'main'

    While ($ArgIdx -LT $Args[0].Count) {
        Switch ($Args[0][$ArgIdx]) {
            { $_ -In '-h', '--help' } {
                Usage
                Exit 0
            }
            { $_ -In '-v', '--version' } {
                $Version = $Args[0][$ArgIdx + 1]
                $ArgIdx += 2
                Break
            }
            '--user' {
                $Target = 'User'
                $ArgIdx += 1
                Break
            }
            Default {
                ErrorUsage "No such option '$($Args[0][$ArgIdx])'"
            }
        }
    }

    CheckEnvironment "$Target"
    $Source = "https://raw.githubusercontent.com/0xO0O0/stinkyboots/$Version/bootware.ps1"
    If ($Target -Eq 'User') {
        $Dest = "$Env:AppData/Bootware/bootware.ps1"
    }
    Else {
        $Dest = 'C:/Program Files/Bootware/bootware.ps1'
    }

    $DestDir = Split-Path -Path "$Dest" -Parent
    # Explicit path update needed, since SetEnvironmentVariable does not seem to
    # instantly take effect.
    $Env:Path = "$DestDir" + ";$Env:Path"

    $Path = [Environment]::GetEnvironmentVariable('Path', "$Target")
    If (-Not ($Path -Like "*$DestDir*")) {
        [System.Environment]::SetEnvironmentVariable(
            'Path', "$DestDir" + ";$Path", "$Target"
        )
    }

    Log 'Installing Bootware'

    New-Item -Force -ItemType Directory -Path "$DestDir" | Out-Null
    DownloadFile "$Source" "$Dest"
    InstallCompletion "$Version"
    Log "Installed $(bootware --version)"
}

# Only run Main if invoked as script. Otherwise import functions as library.
If ($MyInvocation.InvocationName -NE '.') {
    Main $Args
}
