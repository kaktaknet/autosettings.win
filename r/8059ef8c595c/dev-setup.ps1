<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): по ЯВНОМУ выбору дописывает в настройки Git текущего пользователя (--global)
  ключи, которых там ещё нет (init.defaultBranch, core.longpaths, core.editor; при установленном delta - его ключи и zdiff3), и в
  настройки VS Code и уже запускавшихся форков (Cursor, VSCodium, Kiro, Windsurf, Trae) - телеметрию «off», автосохранение и
  терминал (PowerShell 7 и Nerd Font, если они стоят), тоже только недостающие ключи; файл с комментариями не трогает. По
  отдельному выбору ставит расширения Claude Code и Codex из магазина редактора. До правки записывает снимок, возврат снимает
  ровно своё. Прав администратора не просит, из сети качает только расширения из магазина редактора.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$script:DsGitSnapId = 'dev-git'
$script:DsCodeDefaults = [ordered]@{ 'telemetry.telemetryLevel' = 'off'; 'files.autoSave' = 'afterDelay' }
$script:DsRuPack = 'MS-CEINTL.vscode-language-pack-ru'
$script:DsExtSnapId = 'dev-ext'
$script:DsAgentExts = @('anthropic.claude-code', 'openai.chatgpt')
$script:DsEditors = @(
    @{ Name = 'VS Code';  Dir = 'Code';     Proc = 'Code';     Cli = 'code';     Snap = 'dev-vscode' },
    @{ Name = 'Cursor';   Dir = 'Cursor';   Proc = 'Cursor';   Cli = 'cursor';   Snap = 'dev-cursor' },
    @{ Name = 'VSCodium'; Dir = 'VSCodium'; Proc = 'VSCodium'; Cli = 'codium';   Snap = 'dev-vscodium' },
    @{ Name = 'Kiro';     Dir = 'Kiro';     Proc = 'Kiro';     Cli = 'kiro';     Snap = 'dev-kiro' },
    @{ Name = 'Windsurf'; Dir = 'Windsurf'; Proc = 'Windsurf'; Cli = 'windsurf'; Snap = 'dev-windsurf' },
    @{ Name = 'Trae';     Dir = 'Trae';     Proc = 'Trae';     Cli = 'trae';     Snap = 'dev-trae' }
)
$script:DsGitDeltaKeys = [ordered]@{ 'core.pager' = 'delta'; 'interactive.diffFilter' = 'delta --color-only'; 'delta.navigate' = 'true'; 'merge.conflictStyle' = 'zdiff3' }

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
    $keys = [ordered]@{ 'init.defaultBranch' = 'main'; 'core.longpaths' = 'true'; 'core.editor' = $editor }
    if (Get-Command delta -CommandType Application -ErrorAction SilentlyContinue) {
        foreach ($k in $script:DsGitDeltaKeys.Keys) { $keys[$k] = $script:DsGitDeltaKeys[$k] }
    }
    return $keys
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
    $allowed = @((Get-DsGitKeys).Keys) + @($script:DsGitDeltaKeys.Keys)
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

function Get-DsCodeSettings($Ed) {
    $app = [Environment]::GetFolderPath('ApplicationData')
    if (-not $app) { return $null }
    $user = Join-Path (Join-Path $app $Ed.Dir) 'User'
    if ($Ed.Dir -ne 'Code' -and -not (Test-Path -LiteralPath $user)) { return $null }
    return (Join-Path $user 'settings.json')
}

function Get-DsFoundEditors { return @($script:DsEditors | Where-Object { Get-DsCodeSettings $_ }) }

function Get-DsHash([string]$Text) { return (Get-TextHash $Text) }

function Read-DsText([string]$Path) {
    if (Test-Path -LiteralPath $Path) { return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) }
    return ''
}

function Test-DsCodeRunning($Ed) { return [bool](Get-Process -Name $Ed.Proc -ErrorAction SilentlyContinue) }

function Test-DsRussianUi { return ((Get-UICulture).Name -like 'ru*') }

function Test-DsNerdFont {
    $file = $script:TermFontInstallId + 'NerdFont-Regular.ttf'
    foreach ($dir in @((Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Microsoft\Windows\Fonts'), [Environment]::GetFolderPath('Fonts'))) {
        if ($dir -and (Test-Path -LiteralPath (Join-Path $dir $file))) { return $true }
    }
    return $false
}

function Get-DsCodeDefaults {
    $d = [ordered]@{}
    foreach ($k in $script:DsCodeDefaults.Keys) { $d[$k] = $script:DsCodeDefaults[$k] }
    if (Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue) { $d['terminal.integrated.defaultProfile.windows'] = 'PowerShell' }
    if (Test-DsNerdFont) { $d['terminal.integrated.fontFamily'] = $script:TermFontFamily }
    return $d
}

function Get-DsCli($Ed) { return (Get-Command $Ed.Cli -ErrorAction SilentlyContinue | Select-Object -First 1) }

function Invoke-DsCodeSet($Ed) {
    $cfg = Get-DsCodeSettings $Ed
    if (-not $cfg) { return }
    $dir = Split-Path -Parent $cfg
    try { Assert-SafeUserPath $cfg } catch { Add-Outcome 'fail' ($script:S.DsCodeFail -f $Ed.Name); return }
    $existed = Test-Path -LiteralPath $cfg
    $text = Read-DsText $cfg
    $r = Get-JsonMerged $text (Get-DsCodeDefaults)
    if ($null -eq $r) { Add-Outcome 'warn' ($script:S.DsCodeComments -f $Ed.Name); return }
    if ($r.Added.Count -gt 0) {
        $snapDir = Get-PrivateCopyDir
        if (Get-LatestIn $snapDir $Ed.Snap) { Add-Outcome 'warn' ($script:S.DsCodeSnapHeld -f $Ed.Name); return }
        [void](Write-SnapshotFile @(@{ File = $cfg; Existed = $existed; Old = $text; Written = (Get-DsHash $r.Text) }) $Ed.Snap (Get-Date -Format 'yyyyMMdd-HHmmss') $snapDir)
        if (-not (Test-Path -LiteralPath $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
        [IO.File]::WriteAllText($cfg, $r.Text, (New-Object Text.UTF8Encoding $false))
        foreach ($k in $r.Added) { Add-Outcome 'note' ($script:S.DsCodeKey -f $Ed.Name, $k) }
        Add-Outcome 'ok' ($script:S.DsCodeDone -f $Ed.Name)
    }
    else { Add-Outcome 'ok' ($script:S.DsCodeAlready -f $Ed.Name) }
    if ((Test-DsRussianUi) -and (Get-DsCli $Ed)) {
        Write-Live $script:S.DsRuName
        $rc = Invoke-Quiet $Ed.Cli @('--install-extension', $script:DsRuPack)
        Clear-Live
        if ($rc -eq 0) { Add-Outcome 'ok' ($script:S.DsRuDone -f $Ed.Name) } else { Add-Outcome 'warn' ($script:S.DsRuFail -f $Ed.Name) }
    }
    if (Test-DsCodeRunning $Ed) { Add-Outcome 'note' ($script:S.DsCodeRestart -f $Ed.Name) }
}

function Invoke-DsCodeRevert($Ed) {
    $path = Get-LatestIn (Get-PrivateCopyDir) $Ed.Snap
    if (-not $path) { return $false }
    $e = $null
    try { $e = @((Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json).entries)[0] } catch {}
    $cfg = Get-DsCodeSettings $Ed
    if ($null -eq $e -or -not $cfg -or "$($e.File)" -ne $cfg) { Add-Outcome 'fail' $script:S.DsBadSnap; return $true }
    try { Assert-SafeUserPath $cfg } catch { Add-Outcome 'fail' ($script:S.DsCodeFail -f $Ed.Name); return $true }
    $now = Read-DsText $cfg
    if ((Get-DsHash $now) -ne "$($e.Written)") { Add-Outcome 'warn' ($script:S.DsCodeChanged -f $Ed.Name); return $true }
    try {
        if ($e.Existed) { [IO.File]::WriteAllText($cfg, "$($e.Old)", (New-Object Text.UTF8Encoding $false)) }
        else { Remove-Item -LiteralPath $cfg -Force -ErrorAction Stop }
        Remove-SnapshotFiles $path
        Add-Outcome 'ok' ($script:S.DsCodeBack -f $Ed.Name)
    }
    catch { Add-Outcome 'fail' ($script:S.DsCodeFail -f $Ed.Name) }
    return $true
}

function Invoke-DsEditorsSet {
    Start-Work
    foreach ($ed in (Get-DsFoundEditors)) { Invoke-DsCodeSet $ed }
    Show-Outcome
}

function Invoke-DsEditorsRevert {
    Start-Work
    $any = $false
    foreach ($ed in $script:DsEditors) { if (Invoke-DsCodeRevert $ed) { $any = $true } }
    if (-not $any) { Add-Outcome 'warn' $script:S.DsNoSnap }
    Show-Outcome
}

function Get-DsExtensions($Cli) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { return @(& $Cli --list-extensions 2>$null | ForEach-Object { "$_".Trim().ToLowerInvariant() }) }
    catch { return @() }
    finally { $ErrorActionPreference = $old }
}

function Invoke-DsExtSet {
    Start-Work
    $snapDir = Get-PrivateCopyDir
    if (Get-LatestIn $snapDir $script:DsExtSnapId) { Add-Outcome 'warn' ($script:S.DsCodeSnapHeld -f $script:S.DsExtName); Show-Outcome; return }
    $todo = @()
    foreach ($ed in $script:DsEditors) {
        if (-not (Get-DsCli $ed)) { continue }
        $have = Get-DsExtensions $ed.Cli
        foreach ($x in $script:DsAgentExts) {
            if ($have -contains $x) { Add-Outcome 'ok' ($script:S.DsExtHave -f $ed.Name, $x) }
            else { $todo += @{ Cli = $ed.Cli; Name = $ed.Name; Ext = $x } }
        }
    }
    if ($todo.Count -eq 0) {
        if (@($script:Outcome).Count -eq 0) { Add-Outcome 'warn' $script:S.DsExtNoEditor }
        Show-Outcome; return
    }
    [void](Write-SnapshotFile @($todo | ForEach-Object { @{ Cli = $_.Cli; Ext = $_.Ext } }) $script:DsExtSnapId (Get-Date -Format 'yyyyMMdd-HHmmss') $snapDir)
    foreach ($t in $todo) {
        Write-Live $script:S.DsExtName
        $rc = Invoke-Quiet $t.Cli @('--install-extension', $t.Ext)
        Clear-Live
        if ($rc -eq 0) { Add-Outcome 'ok' ($script:S.DsExtDone -f $t.Name, $t.Ext) } else { Add-Outcome 'warn' ($script:S.DsExtFail -f $t.Name, $t.Ext) }
    }
    Show-Outcome
}

function Invoke-DsExtRevert {
    $path = Get-LatestIn (Get-PrivateCopyDir) $script:DsExtSnapId
    Start-Work
    if (-not $path) { Add-Outcome 'warn' $script:S.DsNoSnap; Show-Outcome; return }
    $entries = $null
    try { $entries = @((Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json).entries) } catch {}
    if ($null -eq $entries) { Add-Outcome 'fail' $script:S.DsBadSnap; Show-Outcome; return }
    $clis = @($script:DsEditors | ForEach-Object { $_.Cli })
    $failed = 0
    foreach ($e in $entries) {
        $cli = "$($e.Cli)"; $ext = "$($e.Ext)"
        if (-not ($clis -contains $cli) -or -not ($script:DsAgentExts -contains $ext)) { $failed++; continue }
        if (-not (Get-Command $cli -ErrorAction SilentlyContinue)) { continue }
        Write-Live $script:S.DsExtName
        if ((Invoke-Quiet $cli @('--uninstall-extension', $ext)) -ne 0) { $failed++ }
        Clear-Live
    }
    if ($failed -eq 0) { Remove-SnapshotFiles $path; Add-Outcome 'ok' $script:S.DsExtBack } else { Add-Outcome 'warn' ($script:S.DsPartial -f $failed) }
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
        Write-Host ('  [5] ' + $script:S.DsExtItem)
        Write-Host ('  [6] ' + $script:S.DsExtRevertItem)
        Write-Host ''
        Write-Host ('  ' + $script:S.DsActions)
        Write-Host ''
        $ans = (Read-Host ('  ' + $script:S.Choice)).Trim()
        if ($ans -eq '0' -or $ans -eq '') { return }
        switch ($ans) {
            '1' { if (Test-Yes (Read-Host ('  ' + $script:S.DsGitAsk))) { Invoke-DsGitSet } }
            '2' { Invoke-DsGitRevert }
            '3' { if (Test-Yes (Read-Host ('  ' + $script:S.DsCodeAsk))) { Invoke-DsEditorsSet } }
            '4' { Invoke-DsEditorsRevert }
            '5' { if (Test-Yes (Read-Host ('  ' + $script:S.DsExtAsk))) { Invoke-DsExtSet } }
            '6' { Invoke-DsExtRevert }
            default { Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow }
        }
        Pause-Return
    }
}
