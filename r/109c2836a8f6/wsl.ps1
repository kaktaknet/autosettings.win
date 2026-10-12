$script:WslDistro = 'Ubuntu-26.04'

function Get-WslExe {
    $w = Resolve-ExePath 'wsl'
    if (-not $w) { return $null }
    if (-not (Test-TrustedExe $w @($script:PinMicrosoft))) { return $null }
    return $w
}

function Test-WslDistroPresent($Wsl, $Name) {
    $prev = $env:WSL_UTF8
    $env:WSL_UTF8 = '1'
    try {
        $out = ((& $Wsl --list --quiet 2>$null) -join "`n") -replace "`0", ''
        foreach ($line in ($out -split "`r?`n")) { if ($line.Trim() -eq $Name) { return $true } }
        return $false
    }
    catch { return $false }
    finally { $env:WSL_UTF8 = $prev }
}

function Invoke-WslRevert {
    $wsl = Get-WslExe
    if (-not $wsl) { Write-Host ''; Write-Host ('  ' + $script:S.WslNoWsl) -ForegroundColor Yellow; return }
    if (-not (Test-WslDistroPresent $wsl $script:WslDistro)) {
        Write-Host ''; Write-Host ('  ' + $script:S.WslRevertNone) -ForegroundColor Yellow; return
    }
    Write-Host ''
    $ans = (Read-Host ('  ' + $script:S.WslRevertAsk)).Trim().ToLower()
    if (-not (Test-Yes $ans)) { return }
    if ((Invoke-Quiet $wsl @('--unregister', $script:WslDistro)) -eq 0) { Write-Host ('  ' + $script:S.WslReverted) -ForegroundColor Green }
    else { Write-Host ('  ' + $script:S.WslRevertFail) -ForegroundColor Red }
}

function Invoke-WslScreen {
    while ($true) {
        Write-Host ''
        Write-Host ('  ' + $script:S.WslTitle) -ForegroundColor Cyan
        Write-Host ''
        foreach ($l in $script:S.WslWarn) { Write-Host ('  ' + $l) -ForegroundColor DarkGray }
        Write-Host ''
        Write-Host ('  ' + $script:S.WslActions)
        Write-Host ''
        $ans = (Read-Host ('  ' + $script:S.Choice)).Trim().ToLower()

        if ($ans -eq '0' -or $ans -eq '') { return }
        if ($ans -eq 'r' -or $ans -eq 'р') { Invoke-WslRevert; Pause-Return; continue }
        if (-not (Test-Yes $ans)) { continue }

        $wsl = Get-WslExe
        if (-not $wsl) { Write-Host ''; Write-Host ('  ' + $script:S.WslNoWsl) -ForegroundColor Yellow; Pause-Return; return }
        if (Test-WslDistroPresent $wsl $script:WslDistro) {
            Write-Host ''; Write-Host ('  ' + $script:S.WslPresent) -ForegroundColor Yellow; Pause-Return; return
        }

        Write-Host ''
        Write-Host ('  ' + $script:S.WslInstalling)
        try {
            $p = Start-Process -FilePath $wsl -ArgumentList @('--install', '--distribution', $script:WslDistro) -Verb RunAs -Wait -PassThru
            if ($p -and $p.ExitCode -eq 0) {
                Write-Host ('  ' + $script:S.WslDone) -ForegroundColor Green
                Write-Host ('  ' + $script:S.WslReboot) -ForegroundColor Yellow
            }
            else { Write-Host ('  ' + $script:S.WslFail) -ForegroundColor Yellow }
        }
        catch { Write-Host ('  ' + $script:S.WslFail) -ForegroundColor Yellow }
        Pause-Return
        return
    }
}
