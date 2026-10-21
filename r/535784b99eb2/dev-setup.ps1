<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): по ЯВНОМУ выбору дописывает в настройки Git текущего пользователя (--global)
  три ключа, которых там ещё нет (init.defaultBranch, core.longpaths, core.editor), и в настройки VS Code пользователя - телеметрию
  «off» и автосохранение, тоже только недостающие ключи; файл с комментариями не трогает. До правки записывает снимок, возврат
  снимает ровно своё. Прав администратора не просит, из сети ничего не качает, кроме русского пакета VS Code из его магазина.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$script:DsGitSnapId = 'dev-git'
$script:DsCodeSnapId = 'dev-vscode'
$script:DsCodeDefaults = [ordered]@{ 'telemetry.telemetryLevel' = 'off'; 'files.autoSave' = 'afterDelay' }
$script:DsRuPack = 'MS-CEINTL.vscode-language-pack-ru'

function Get-DsGit {
    $c = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { return $c.Path }
    if ($env:ProgramFiles) {
        $p = Join-Path (Join-Path (Join-Path $env:ProgramFiles 'Git') 'cmd') 'git.exe'
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

function Test-DsCode { return [bool](Get-Command code -ErrorAction SilentlyContinue) }

function Get-DsGitKeys {
    $editor = 'notepad'
    if (Test-DsCode) { $editor = 'code --wait' }
    return [ordered]@{ 'init.defaultBranch' = 'main'; 'core.longpaths' = 'true'; 'core.editor' = $editor }
}

function Get-DsGitValue([string]$Git, [string]$Key) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $v = @(& $Git config --global --get-all $Key 2>$null)
        if ($LASTEXITCODE -ne 0) { return $null }
        return $v
    }
    finally { $ErrorActionPreference = $old }
}

function Invoke-DsGitSet {
    $git = Get-DsGit
    if (-not $git) { Start-Work; Add-Outcome 'warn' $script:S.DsNoGit; Show-Outcome; return }
    $keys = Get-DsGitKeys
    $todo = @($keys.Keys | Where-Object { $null -eq (Get-DsGitValue $git $_) })
    Start-Work
    if ($todo.Count -eq 0) { Add-Outcome 'ok' $script:S.DsGitAlready; Show-Outcome; return }
    $dir = Get-PrivateCopyDir
    $entries = @($todo | ForEach-Object { @{ Key = $_; Value = $keys[$_] } })
    $prev = Get-LatestIn $dir $script:DsGitSnapId
    if ($prev) {
        try { $entries += @((Get-Content -LiteralPath $prev -Raw -Encoding UTF8 | ConvertFrom-Json).entries | ForEach-Object { @{ Key = "$($_.Key)"; Value = "$($_.Value)" } }) } catch {}
    }
    [void](Write-SnapshotFile $entries $script:DsGitSnapId (Get-Date -Format 'yyyyMMdd-HHmmss') $dir)
    if ($prev) { Remove-SnapshotFiles $prev }
    Write-Live $script:S.DsGitName
    $failed = 0
    foreach ($k in $todo) {
        if ((Invoke-Quiet $git @('config', '--global', $k, $keys[$k])) -ne 0) { $failed++ }
        else { Add-Outcome 'note' ($script:S.DsGitKey -f $k, $keys[$k]) }
    }
    Clear-Live
    if ($failed -eq 0) { Add-Outcome 'ok' $script:S.DsGitDone } else { Add-Outcome 'warn' ($script:S.DsPartial -f $failed) }
    Show-Outcome
}

function Invoke-DsGitRevert {
    $git = Get-DsGit
    $path = Get-LatestIn (Get-PrivateCopyDir) $script:DsGitSnapId
    if (-not $path) { Start-Work; Add-Outcome 'warn' $script:S.DsNoSnap; Show-Outcome; return }
    if (-not $git) { Start-Work; Add-Outcome 'warn' $script:S.DsNoGit; Show-Outcome; return }
    $entries = $null
    try { $entries = @((Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json).entries) } catch {}
    if ($null -eq $entries) { Start-Work; Add-Outcome 'fail' $script:S.DsBadSnap; Show-Outcome; return }
    $allowed = @((Get-DsGitKeys).Keys)
    Start-Work
    Write-Live $script:S.DsGitName
    $failed = 0
    $refused = 0
    foreach ($e in $entries) {
        $k = "$($e.Key)"
        if (-not ($allowed -contains $k)) { $refused++; continue }
        $now = @(Get-DsGitValue $git $k)
        if ($now.Count -eq 1 -and "$($now[0])" -eq "$($e.Value)") {
            if ((Invoke-Quiet $git @('config', '--global', '--unset', $k)) -ne 0) { $failed++ }
        }
        elseif ($now.Count -gt 0 -and $null -ne $now[0]) { Add-Outcome 'note' ($script:S.DsGitKept -f $k) }
    }
    Clear-Live
    if ($failed -eq 0 -and $refused -eq 0) { Remove-SnapshotFiles $path; Add-Outcome 'ok' $script:S.DsGitBack }
    else { Add-Outcome 'warn' ($script:S.DsPartial -f ($failed + $refused)) }
    Show-Outcome
}

function Get-DsCodeSettings {
    $app = [Environment]::GetFolderPath('ApplicationData')
    if (-not $app) { return $null }
    return (Join-Path (Join-Path (Join-Path $app 'Code') 'User') 'settings.json')
}

function Get-DsHash([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))) -replace '-', '') }
    finally { $sha.Dispose() }
}

function Read-DsText([string]$Path) {
    if (Test-Path -LiteralPath $Path) { return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) }
    return ''
}

function Test-DsCodeRunning { return [bool](Get-Process -Name 'Code' -ErrorAction SilentlyContinue) }

function Test-DsRussianUi { return ((Get-UICulture).Name -like 'ru*') }

function Invoke-DsCodeSet {
    $cfg = Get-DsCodeSettings
    if (-not $cfg) { Start-Work; Add-Outcome 'fail' $script:S.DsCodeFail; Show-Outcome; return }
    $dir = Split-Path -Parent $cfg
    try { Assert-SafeUserPath $cfg } catch { Start-Work; Add-Outcome 'fail' $script:S.DsCodeFail; Show-Outcome; return }
    $existed = Test-Path -LiteralPath $cfg
    $text = Read-DsText $cfg
    $r = Get-JsonMerged $text $script:DsCodeDefaults
    Start-Work
    if ($null -eq $r) { Add-Outcome 'warn' $script:S.DsCodeComments; Show-Outcome; return }
    if ($r.Added.Count -gt 0) {
        $snapDir = Get-PrivateCopyDir
        if (Get-LatestIn $snapDir $script:DsCodeSnapId) { Add-Outcome 'warn' $script:S.DsCodeSnapHeld; Show-Outcome; return }
        [void](Write-SnapshotFile @(@{ File = $cfg; Existed = $existed; Old = $text; Written = (Get-DsHash $r.Text) }) $script:DsCodeSnapId (Get-Date -Format 'yyyyMMdd-HHmmss') $snapDir)
        if (-not (Test-Path -LiteralPath $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
        [IO.File]::WriteAllText($cfg, $r.Text, (New-Object Text.UTF8Encoding $false))
        foreach ($k in $r.Added) { Add-Outcome 'note' ($script:S.DsCodeKey -f $k) }
        Add-Outcome 'ok' $script:S.DsCodeDone
    }
    else { Add-Outcome 'ok' $script:S.DsCodeAlready }
    if ((Test-DsRussianUi) -and (Test-DsCode)) {
        Write-Live $script:S.DsRuName
        $rc = Invoke-Quiet 'code' @('--install-extension', $script:DsRuPack)
        Clear-Live
        if ($rc -eq 0) { Add-Outcome 'ok' $script:S.DsRuDone } else { Add-Outcome 'warn' $script:S.DsRuFail }
    }
    if (Test-DsCodeRunning) { Add-Outcome 'note' $script:S.DsCodeRestart }
    Show-Outcome
}

function Invoke-DsCodeRevert {
    $path = Get-LatestIn (Get-PrivateCopyDir) $script:DsCodeSnapId
    if (-not $path) { Start-Work; Add-Outcome 'warn' $script:S.DsNoSnap; Show-Outcome; return }
    $e = $null
    try { $e = @((Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json).entries)[0] } catch {}
    $cfg = Get-DsCodeSettings
    Start-Work
    $failed = 0
    $refused = 0
    if ($null -eq $e -or "$($e.File)" -ne $cfg) { $refused++ }
    else {
        try { Assert-SafeUserPath $cfg } catch { Add-Outcome 'fail' $script:S.DsCodeFail; Show-Outcome; return }
        $now = Read-DsText $cfg
        if ((Get-DsHash $now) -ne "$($e.Written)") { Add-Outcome 'warn' $script:S.DsCodeChanged; Show-Outcome; return }
        try {
            if ($e.Existed) { [IO.File]::WriteAllText($cfg, "$($e.Old)", (New-Object Text.UTF8Encoding $false)) }
            else { Remove-Item -LiteralPath $cfg -Force -ErrorAction Stop }
        }
        catch { $failed++ }
    }
    if ($failed -eq 0 -and $refused -eq 0) { Remove-SnapshotFiles $path; Add-Outcome 'ok' $script:S.DsCodeBack }
    elseif ($refused -gt 0) { Add-Outcome 'fail' $script:S.DsBadSnap }
    else { Add-Outcome 'fail' $script:S.DsCodeFail }
    Show-Outcome
}

function Invoke-DevSetupScreen {
    while ($true) {
        Write-Host ''
        Write-Host ('  ' + $script:S.DsTitle) -ForegroundColor Cyan
        Write-Host ''
        foreach ($l in $script:S.DsLead) { Write-Host ('  ' + $l) -ForegroundColor DarkGray }
        Write-Host ''
        Write-Host ('  [1] ' + $script:S.DsGitItem)
        Write-Host ('  [2] ' + $script:S.DsGitRevertItem)
        Write-Host ('  [3] ' + $script:S.DsCodeItem)
        Write-Host ('  [4] ' + $script:S.DsCodeRevertItem)
        Write-Host ''
        Write-Host ('  ' + $script:S.DsActions)
        Write-Host ''
        $ans = (Read-Host ('  ' + $script:S.Choice)).Trim()
        if ($ans -eq '0' -or $ans -eq '') { return }
        switch ($ans) {
            '1' { if (Test-Yes (Read-Host ('  ' + $script:S.DsGitAsk))) { Invoke-DsGitSet } }
            '2' { Invoke-DsGitRevert }
            '3' { if (Test-Yes (Read-Host ('  ' + $script:S.DsCodeAsk))) { Invoke-DsCodeSet } }
            '4' { Invoke-DsCodeRevert }
            default { Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow }
        }
        Pause-Return
    }
}
