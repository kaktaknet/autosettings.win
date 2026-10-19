<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): по ЯВНОМУ выбору ставит WSL 2 и Ubuntu подписанным Microsoft wsl.exe с фиксированными аргументами;
  отмена удаляет поставленный дистрибутив после отдельного подтверждения.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

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
    Start-Work
    Write-Live 'WSL'
    if ((Invoke-Quiet $wsl @('--unregister', $script:WslDistro)) -eq 0) { Add-Outcome 'ok' $script:S.WslReverted }
    else { Add-Outcome 'fail' $script:S.WslRevertFail }
    Show-Outcome
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
        if ((Get-Key $ans) -eq 'r') { Invoke-WslRevert; Pause-Return; continue }
        if (-not (Test-Yes $ans)) { continue }

        $wsl = Get-WslExe
        if (-not $wsl) { Write-Host ''; Write-Host ('  ' + $script:S.WslNoWsl) -ForegroundColor Yellow; Pause-Return; return }
        if (Test-WslDistroPresent $wsl $script:WslDistro) {
            Write-Host ''; Write-Host ('  ' + $script:S.WslPresent) -ForegroundColor Yellow; Pause-Return; return
        }

        Start-Work
        Write-Live 'WSL 2 + Ubuntu'
        try {
            $p = Start-Process -FilePath $wsl -ArgumentList @('--install', '--distribution', $script:WslDistro) -Verb RunAs -Wait -PassThru
            if ($p -and $p.ExitCode -eq 0) {
                Add-Outcome 'ok' $script:S.WslDone
                Add-Outcome 'warn' $script:S.WslReboot
            }
            else { Add-Outcome 'fail' $script:S.WslFail }
        }
        catch { Add-Outcome 'fail' $script:S.WslFail }
        Show-Outcome
        Pause-Return
        return
    }
}
