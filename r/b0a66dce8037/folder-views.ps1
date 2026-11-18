<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): по ЯВНОМУ выбору сбрасывает запомненные виды папок Проводника текущего
  пользователя (разделы BagMRU, Bags, Streams\Defaults и FolderTypes в HKCU), сохраняя раскладку значков рабочего стола; по
  второму пункту после того же сброса копирует шаблоны папок Windows из HKLM в HKCU (reg copy, HKLM только читается) и
  ставит в них вид «Таблица». До сброса выгружает
  каждый раздел целиком через reg.exe export в личную папку; возврат удаляет раздел и загружает выгрузку обратно. Прав
  администратора не просит.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$script:FvSnapId = 'folder-views'
$script:FvKeys = @(
    @{ Id = 'lsbagmru'; Key = 'HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU' },
    @{ Id = 'lsbags';   Key = 'HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags' },
    @{ Id = 'bagmru';   Key = 'HKCU\Software\Microsoft\Windows\Shell\BagMRU' },
    @{ Id = 'bags';     Key = 'HKCU\Software\Microsoft\Windows\Shell\Bags' },
    @{ Id = 'streams';  Key = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Streams\Defaults' },
    @{ Id = 'foldertypes'; Key = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FolderTypes' }
)
$script:FvTypesSource = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderTypes'
$script:FvTypesUser = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FolderTypes'
$script:FvDesktop = 'HKCU\Software\Microsoft\Windows\Shell\Bags\1\Desktop'

function Get-FvReg {
    $sys = [Environment]::SystemDirectory
    if (-not $sys) { return $null }
    $p = Join-Path $sys 'reg.exe'
    if (Test-Path -LiteralPath $p) { return $p }
    return $null
}

function Test-FvKey([string]$Key) { return (Test-Path -LiteralPath ('Registry::' + $Key)) }

function Export-FvKey([string]$Reg, [string]$Key, [string]$File) {
    return ((Invoke-Quiet $Reg @('export', $Key, $File, '/y')) -eq 0 -and (Test-Path -LiteralPath $File))
}

function Invoke-FvReset([bool]$Details) {
    $reg = Get-FvReg
    Start-Work
    if (-not $reg) { Add-Outcome 'fail' $script:S.FvNoReg; Show-Outcome; return }
    $root = Get-PrivateCopyDir
    if (Get-LatestIn $root $script:FvSnapId) { Add-Outcome 'warn' $script:S.FvSnapHeld; Show-Outcome; return }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dir = Join-Path $root ($script:FvSnapId + '-' + $stamp)
    [void](New-Item -ItemType Directory -Path $dir -Force)
    Write-Live $script:S.FvName
    $entries = @()
    foreach ($k in $script:FvKeys) {
        if (-not (Test-FvKey $k.Key)) { $entries += @{ Id = $k.Id; Existed = $false }; continue }
        if (-not (Export-FvKey $reg $k.Key (Join-Path $dir ($k.Id + '.reg')))) { Clear-Live; Add-Outcome 'fail' $script:S.FvExportFail; Show-Outcome; return }
        $entries += @{ Id = $k.Id; Existed = $true }
    }
    $desk = Join-Path $dir 'desktop.reg'
    $hasDesk = (Test-FvKey $script:FvDesktop) -and (Export-FvKey $reg $script:FvDesktop $desk)
    [void](Write-SnapshotFile $entries $script:FvSnapId $stamp $root)
    $failed = 0
    foreach ($k in $script:FvKeys) {
        if (-not (Test-FvKey $k.Key)) { continue }
        if ((Invoke-Quiet $reg @('delete', $k.Key, '/f')) -ne 0) { $failed++ }
    }
    if ($hasDesk) { [void](Invoke-Quiet $reg @('import', $desk)) }
    $table = $true
    if ($Details) { $table = Set-FvDetails $reg }
    Restart-FvExplorer
    Clear-Live
    if ($failed -ne 0) { Add-Outcome 'warn' ($script:S.FvPartial -f $failed) }
    elseif (-not $table) { Add-Outcome 'warn' $script:S.FvDetailsFail }
    elseif ($Details) { Add-Outcome 'ok' $script:S.FvDetailsDone }
    else { Add-Outcome 'ok' $script:S.FvDone }
    Show-Outcome
}

function Set-FvDetails([string]$Reg) {
    $a = @('copy', $script:FvTypesSource, $script:FvTypesUser, '/s', '/f')
    if ([Environment]::Is64BitOperatingSystem) { $a += '/reg:64' }
    if ((Invoke-Quiet $Reg $a) -ne 0) { return $false }
    try {
        foreach ($ft in @(Get-ChildItem -LiteralPath ('Registry::' + $script:FvTypesUser) -ErrorAction Stop)) {
            if ("$($ft.GetValue('CanonicalName'))" -eq 'HomeFolder') { continue }
            foreach ($v in @(Get-ChildItem -LiteralPath ($ft.PSPath + '\TopViews') -ErrorAction SilentlyContinue)) {
                Set-ItemProperty -LiteralPath $v.PSPath -Name 'LogicalViewMode' -Value 1 -Type DWord -ErrorAction Stop
                Set-ItemProperty -LiteralPath $v.PSPath -Name 'IconSize' -Value 16 -Type DWord -ErrorAction Stop
            }
        }
    }
    catch { return $false }
    return $true
}

function Restart-FvExplorer {
    foreach ($p in @(Get-Process -Name 'explorer' -ErrorAction SilentlyContinue)) {
        try { Stop-Process -Id $p.Id -Force -ErrorAction Stop } catch {}
    }
    Start-Sleep -Milliseconds 800
    if (-not (Get-Process -Name 'explorer' -ErrorAction SilentlyContinue)) {
        $win = [Environment]::GetFolderPath('Windows')
        if ($win) { Start-Process -FilePath (Join-Path $win 'explorer.exe') }
    }
}

function Invoke-FvRevert {
    $reg = Get-FvReg
    $path = Get-LatestIn (Get-PrivateCopyDir) $script:FvSnapId
    Start-Work
    if (-not $path) { Add-Outcome 'warn' $script:S.FvNoSnap; Show-Outcome; return }
    if (-not $reg) { Add-Outcome 'fail' $script:S.FvNoReg; Show-Outcome; return }
    $entries = $null
    try { $entries = @((Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json).entries) } catch {}
    if ($null -eq $entries) { Add-Outcome 'fail' $script:S.FvBadSnap; Show-Outcome; return }
    $dir = Join-Path (Split-Path -Parent $path) ([IO.Path]::GetFileNameWithoutExtension($path))
    Write-Live $script:S.FvName
    $failed = 0
    $refused = 0
    foreach ($e in $entries) {
        $k = @($script:FvKeys | Where-Object { $_.Id -eq "$($e.Id)" }) | Select-Object -First 1
        if (-not $k) { $refused++; continue }
        if (Test-FvKey $k.Key) { [void](Invoke-Quiet $reg @('delete', $k.Key, '/f')) }
        if ($e.Existed) {
            $file = Join-Path $dir ($k.Id + '.reg')
            if (-not (Test-Path -LiteralPath $file) -or (Invoke-Quiet $reg @('import', $file)) -ne 0) { $failed++ }
        }
    }
    Restart-FvExplorer
    Clear-Live
    if ($failed -eq 0 -and $refused -eq 0) {
        Remove-SnapshotFiles $path
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        Add-Outcome 'ok' $script:S.FvBack
    }
    else { Add-Outcome 'warn' ($script:S.FvPartial -f ($failed + $refused)) }
    Show-Outcome
}

function Invoke-FolderViewsScreen {
    while ($true) {
        Write-Host ''
        Write-Host ('  ' + $script:S.FvTitle) -ForegroundColor Cyan
        Write-Host ''
        foreach ($l in $script:S.FvLead) { Write-Host ('  ' + $l) -ForegroundColor DarkGray }
        Write-Host ''
        Write-Host ('  [1] ' + $script:S.FvResetItem)
        Write-Host ('  [2] ' + $script:S.FvRevertItem)
        Write-Host ('  [3] ' + $script:S.FvDetailsItem)
        Write-Host ''
        Write-Host ('  ' + $script:S.FvActions)
        Write-Host ''
        $ans = (Read-Host ('  ' + $script:S.Choice)).Trim()
        if ($ans -eq '0' -or $ans -eq '') { return }
        switch ($ans) {
            '1' { if (Test-Yes (Read-Host ('  ' + $script:S.FvAsk))) { Invoke-FvReset $false } }
            '2' { Invoke-FvRevert }
            '3' { if (Test-Yes (Read-Host ('  ' + $script:S.FvDetailsAsk))) { Invoke-FvReset $true } }
            default { Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow }
        }
        Pause-Return
    }
}
