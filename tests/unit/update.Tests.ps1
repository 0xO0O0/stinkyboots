BeforeAll {
    # Path normalization required for Assert-MockCalled parameter filters.
    $Bootware = [System.IO.Path]::GetFullPath("$PSScriptRoot/../../bootware.ps1")
    . "$Bootware"

    Mock DownloadFile { }
    # Mocking Git appears to not work on Windows.
    Function git { Write-Output "git $Args" }
    Mock Test-Path { Write-Output 1 }

    # Avoid overwriting WSL copy of Bootware during tests if installed.
    If (Get-Command wsl -ErrorAction SilentlyContinue) {
        Mock wsl { }
    }
}

Describe 'Update' {
    It 'Subcommand help prints message' {
        $Actual = "$(& "$Bootware" update --help)"
        $Actual | Should -Match 'Update Bootware to latest version'
    }

    It 'Throw error for nonexistant option at end of call' {
        { & "$Bootware" update -v develop notanoption } |
            Should -Throw "Error: No such option 'notanoption'"
    }

    It 'Subcommand passes args to DownloadFile and Git' {
        If (Get-Command bootware -ErrorAction SilentlyContinue) {
            Mock bootware { Write-Output '' }
        }
        Else {
            Function bootware() { Write-Output '' }
        }

        $Env:BOOTWARE_NOLOG = 1
        $BootwareDir = "$(Split-Path -Parent $Bootware)"
        $Expected = "git -C $BootwareDir/repo pull"

        $Actual = "$(& "$Bootware" update --version main)"
        Assert-MockCalled DownloadFile -Times 1 -ParameterFilter {
            $DstFile -Eq "$BootwareDir/bootware.ps1" -And
            $SrcURL -Eq 'https://raw.githubusercontent.com/0xO0O0/stinkyboots/main/bootware.ps1'
        }

        $Actual | Should -Be $Expected
    }
}