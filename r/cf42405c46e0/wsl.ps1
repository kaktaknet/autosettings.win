<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): по ЯВНОМУ выбору ставит WSL 2 и Ubuntu подписанным Microsoft wsl.exe с фиксированными аргументами;
  перед установкой дописывает в %UserProfile%\.wslconfig ключ [experimental] sparseVhd=true, если его там нет (снимок файла до записи);
  отмена возвращает файл, если он не менялся, и удаляет поставленный дистрибутив после отдельного подтверждения.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$script:WslDistro = 'Ubuntu-26.04'
$script:WslCfgSnapId = 'dev-wslconfig'

function Get-WslConfigPath {
    $up = [Environment]::GetFolderPath('UserProfile')
    if (-not $up) { return $null }
    return (Join-Path $up '.wslconfig')
}

function Get-WslConfigMerged([string]$Text) {
    if ($Text -match '(?im)^\s*sparseVhd\s*=') { return $null }
    $nl = "`r`n"
    if ($Text -match '(?im)^\s*\[experimental\]\s*$') {
        return (([regex]'(?im)^([ \t]*\[experimental\][ \t]*)(?=\r?$)').Replace($Text, '$1' + $nl + 'sparseVhd=true', 1))
    }
    $sep = ''
    if ($Text.Length -gt 0 -and -not $Text.EndsWith("`n")) { $sep = $nl }
    return ($Text + $sep + '[experimental]' + $nl + 'sparseVhd=true' + $nl)
}

function Set-WslConfig {
    $cfg = Get-WslConfigPath
    if (-not $cfg) { return }
    try { Assert-SafeUserPath $cfg } catch { return }
    $existed = Test-Path -LiteralPath $cfg
    $text = Read-WslText $cfg
    $new = Get-WslConfigMerged $text
    if ($null -eq $new) { return }
    $dir = Get-PrivateCopyDir
    if (Get-LatestIn $dir $script:WslCfgSnapId) { return }
    [void](Write-SnapshotFile @(@{ File = $cfg; Existed = $existed; Old = $text; Written = (Get-TextHash $new) }) $script:WslCfgSnapId (Get-Date -Format 'yyyyMMdd-HHmmss') $dir)
    [IO.File]::WriteAllText($cfg, $new, (New-Object Text.UTF8Encoding $false))
    Add-Outcome 'note' $script:S.WslCfgDone
}

function Read-WslText([string]$Path) {
    if (Test-Path -LiteralPath $Path) { return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) }
    return ''
}

function Invoke-WslConfigRevert {
    $path = Get-LatestIn (Get-PrivateCopyDir) $script:WslCfgSnapId
    if (-not $path) { return }
    $e = $null
    try { $e = @((Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json).entries)[0] } catch {}
    $cfg = Get-WslConfigPath
    $failed = 0
    $refused = 0
    if ($null -eq $e -or -not $cfg -or "$($e.File)" -ne $cfg) { $refused++ }
    else {
        try { Assert-SafeUserPath $cfg } catch { return }
        $now = Read-WslText $cfg
        if ((Get-TextHash $now) -ne "$($e.Written)") { Write-Host ''; Write-Host ('  ' + $script:S.WslCfgChanged) -ForegroundColor Yellow; return }
        try {
            if ($e.Existed) { [IO.File]::WriteAllText($cfg, "$($e.Old)", (New-Object Text.UTF8Encoding $false)) }
            else { Remove-Item -LiteralPath $cfg -Force -ErrorAction Stop }
        }
        catch { $failed++ }
    }
    if ($failed -eq 0 -and $refused -eq 0) { Remove-SnapshotFiles $path; Write-Host ''; Write-Host ('  ' + $script:S.WslCfgBack) -ForegroundColor Green }
}

function Get-WslExe {
    $sys = [Environment]::SystemDirectory
    if (-not $sys) { return $null }
    $w = Join-Path $sys 'wsl.exe'
    if (-not (Test-Path -LiteralPath $w)) { return $null }
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
    Invoke-WslConfigRevert
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
        Set-WslConfig
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
