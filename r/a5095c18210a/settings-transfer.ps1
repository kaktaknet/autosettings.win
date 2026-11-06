<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): по ЯВНОМУ выбору сохраняет в файл набора список id применённых на этом
  компьютере настроек (без значений) с контрольной суммой SHA-256 и применяет такой файл после вопроса: значения берутся только из
  паспорта выпуска, id не из паспорта пропускаются. Без меню (параметры строки запуска -Preset, -SetFile, -ExportSet, -DryRun)
  делает то же самое без вопросов; настройки на выбор и модули набора тогда пропускаются и перечисляются в итоге.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$script:SetFormat = 'autosettings-set'
$script:SetVersion = 1
$script:SetMaxIds = 2000

function Get-SetDir {
    $dir = Join-Path $script:UserCopyBase 'settings'
    Assert-SafeUserPath $dir
    foreach ($d in @($script:UserCopyBase, $dir)) {
        if (-not (Test-Path -LiteralPath $d)) { [void](New-Item -ItemType Directory -Path $d -ErrorAction Stop) }
    }
    return $dir
}

function Get-SetDigest($Ids) {
    $text = $script:SetFormat + '/' + $script:SetVersion + "`n" + (@($Ids) -join "`n")
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)) } finally { $sha.Dispose() }
    return (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Get-AppliedIds {
    return @($data.settings | Where-Object { (Test-SettingFits $_) -and (Test-Applied $_) } | ForEach-Object { "$($_.id)" })
}

function Write-SetFile([string]$Path, $Ids) {
    $doc = [ordered]@{ format = $script:SetFormat; version = $script:SetVersion; created = (Get-Date).ToString('s'); settings = @($Ids); sha256 = (Get-SetDigest $Ids) }
    [IO.File]::WriteAllText($Path, ($doc | ConvertTo-Json -Depth 3), (New-Object Text.UTF8Encoding $false))
}

function Read-SetFile([string]$Path) {
    $r = @{ Ok = $false; Settings = @(); Unknown = 0 }
    try { $doc = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) | ConvertFrom-Json } catch { return $r }
    if ("$($doc.format)" -ne $script:SetFormat -or "$($doc.version)" -ne "$($script:SetVersion)") { return $r }
    $ids = @($doc.settings | ForEach-Object { "$_" })
    if ($ids.Count -gt $script:SetMaxIds -or @($ids | Where-Object { $_ -notmatch '^[a-z0-9-]{1,80}$' }).Count -gt 0) { return $r }
    if ("$($doc.sha256)" -ne (Get-SetDigest $ids)) { return $r }
    foreach ($id in $ids) {
        $m = @($data.settings | Where-Object { $_.id -eq $id -and (Test-SettingFits $_) })
        if ($m.Count -gt 0) { $r.Settings += $m[0] } else { $r.Unknown++ }
    }
    $r.Ok = $true
    return $r
}

function Get-SetCommand([string]$Path) {
    return ("& ([scriptblock]::Create((irm https://get.autosettings.win))) -SetFile '" + ($Path -replace "'", "''") + "'")
}

function Invoke-SetExport {
    try { $dir = Get-SetDir } catch { Add-Outcome 'fail' ($script:S.StNoDir -f (Get-ShortError $_)); return $null }
    $ids = Get-AppliedIds
    if ($ids.Count -eq 0) { Add-Outcome 'warn' $script:S.StNothing; return $null }
    $file = Join-Path $dir ('settings-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
    try { Write-SetFile $file $ids } catch { Add-Outcome 'fail' ($script:S.StNoDir -f (Get-ShortError $_)); return $null }
    Add-Outcome 'ok' ($script:S.StExported -f $ids.Count)
    Add-Outcome 'note' $file
    return $file
}

function Invoke-SetImport {
    try { $dir = Get-SetDir } catch { Write-Host ''; Write-Host ('  ' + ($script:S.StNoDir -f (Get-ShortError $_))) -ForegroundColor Yellow; return }
    $files = @(Get-ChildItem -LiteralPath $dir -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name -Descending)
    Write-Host ''
    if ($files.Count -eq 0) { Write-Host ('  ' + ($script:S.StNoFiles -f $dir)) -ForegroundColor Yellow; return }
    for ($i = 0; $i -lt $files.Count; $i++) { Write-Host ('  [{0,2}] {1}' -f ($i + 1), $files[$i].Name) }
    Write-Host ''
    $ans = (Read-Host ('  ' + $script:S.StPickFile)).Trim()
    $num = 0
    if (-not ([int]::TryParse($ans, [ref]$num) -and $num -ge 1 -and $num -le $files.Count)) { return }
    $r = Read-SetFile $files[$num - 1].FullName
    if (-not $r.Ok) { Write-Host ''; Write-Host ('  ' + $script:S.StBadFile) -ForegroundColor Yellow; return }
    $todo = @($r.Settings | Where-Object { -not (Test-Applied $_) })
    Write-Host ''
    if ($r.Unknown -gt 0) { Write-Host ('  ' + ($script:S.StUnknown -f $r.Unknown)) -ForegroundColor DarkGray }
    if ($todo.Count -eq 0) { Write-Host ('  ' + $script:S.StAllThere) -ForegroundColor Green; return }
    if (-not (Test-Yes (Read-Host ('  ' + ($script:S.StImportAsk -f $todo.Count))))) { return }
    Apply-PresetSelection $r.Settings $todo
}

function Invoke-SettingsTransferScreen {
    while ($true) {
        Write-Host ''
        Write-Host ('  ' + $script:S.StTitle) -ForegroundColor Cyan
        Write-Host ''
        foreach ($l in $script:S.StLead) { Write-Host ('  ' + $l) -ForegroundColor DarkGray }
        Write-Host ''
        Write-Host ('  ' + $script:S.StActions)
        Write-Host ''
        $ans = (Read-Host ('  ' + $script:S.Choice)).Trim()
        if ($ans -eq '0' -or $ans -eq '') { return }
        if ($ans -eq '1') {
            Start-Work
            $file = Invoke-SetExport
            if ($file) {
                $cmd = Get-SetCommand $file
                $copied = $false
                try { Add-Type -AssemblyName System.Windows.Forms; [Windows.Forms.Clipboard]::SetText($cmd); $copied = $true } catch {}
                Add-Outcome 'note' $(if ($copied) { $script:S.StCmdCopied } else { $script:S.StCmdShown })
                Add-Outcome 'note' $cmd
            }
            Show-Outcome; Pause-Return; continue
        }
        if ($ans -eq '2') { Invoke-SetImport; Pause-Return; continue }
        Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow; Pause-Return
    }
}

function Invoke-Cli($Opt) {
    if ($Opt.ExportSet) {
        $path = "$($Opt.ExportSet)"
        try {
            $full = [IO.Path]::GetFullPath($path)
            Assert-SafeUserPath $full
            $ids = Get-AppliedIds
            Write-SetFile $full $ids
        }
        catch { Write-Host ($script:S.CliExportFail -f (Get-ShortError $_)); return 2 }
        Write-Host ($script:S.StExported -f $ids.Count)
        return 0
    }
    $settings = @(); $skipped = @()
    if ($Opt.Preset) {
        $p = @($data.presets | Where-Object { $_ -and ("$($_.id)" -eq "$($Opt.Preset)" -or "$($_.id)" -eq ('preset-' + $Opt.Preset)) }) | Select-Object -First 1
        if (-not $p) { Write-Host ($script:S.CliNoPreset -f $Opt.Preset, ((@($data.presets | Where-Object { $_ } | ForEach-Object { $_.id })) -join ', ')); return 2 }
        $all = @(Get-PresetSettings $p)
        $settings = @($all | Where-Object { -not $_.optional })
        $skipped += @($all | Where-Object { $_.optional } | ForEach-Object { Get-Title $_ })
        foreach ($m in @($p.modules)) { if ($m) { $t = $m.title.$($script:Lang); if (-not $t) { $t = $m.title.en }; $skipped += $t } }
    }
    elseif ($Opt.SetFile) {
        $r = Read-SetFile "$($Opt.SetFile)"
        if (-not $r.Ok) { Write-Host $script:S.StBadFile; return 2 }
        if ($r.Unknown -gt 0) { Write-Host ($script:S.StUnknown -f $r.Unknown) }
        $settings = @($r.Settings)
    }
    else { Write-Host $script:S.CliUsage; return 2 }
    $todo = @($settings | Where-Object { -not (Test-Applied $_) })
    if ($Opt.DryRun) {
        Write-Host ($script:S.CliWould -f $todo.Count)
        foreach ($s in $todo) { Write-Host ('  - ' + (Get-Title $s)) }
    }
    elseif ($todo.Count -eq 0) { Write-Host $script:S.StAllThere }
    else { Apply-PresetSelection $settings $todo }
    if ($skipped.Count -gt 0) {
        Write-Host $script:S.CliSkipped
        foreach ($t in $skipped) { Write-Host ('  - ' + $t) }
    }
    if ($Opt.DryRun) { return 0 }
    if (@($todo | Where-Object { -not (Test-Applied $_) }).Count -gt 0) { return 1 }
    return 0
}
