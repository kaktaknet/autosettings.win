<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): по ЯВНОМУ выбору сохраняет список программ через winget export (только источник winget) в папку
  «Документы\AutoSettings.win\programs» и ставит программы из такого файла через winget import после
  вопроса с числом программ; перед установкой файл очищается от всех источников, кроме winget.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

function Get-TransferDir {
    $dir = Join-Path $script:UserCopyBase 'programs'
    Assert-SafeUserPath $dir
    foreach ($d in @($script:UserCopyBase, $dir)) {
        if (-not (Test-Path -LiteralPath $d)) { [void](New-Item -ItemType Directory -Path $d -ErrorAction Stop) }
    }
    return $dir
}

function Invoke-ProgramsExport {
    $winget = Get-WingetExe
    if (-not $winget) { Add-Outcome 'fail' $script:S.PtNoWinget; return }
    try { $dir = Get-TransferDir } catch { Add-Outcome 'fail' ($script:S.PtNoDir -f (Get-ShortError $_)); return }
    $file = Join-Path $dir ('programs-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
    Write-Live $script:S.PtExporting
    $rc = Invoke-Quiet $winget @('export', '--output', $file, '--source', 'winget', '--accept-source-agreements', '--disable-interactivity')
    if ($rc -eq 0 -and (Test-Path -LiteralPath $file)) {
        $count = 0
        try { $count = @((Get-Content -LiteralPath $file -Raw | ConvertFrom-Json).Sources | ForEach-Object { $_.Packages }).Count } catch {}
        Add-Outcome 'ok' ($script:S.PtExported -f $count)
        Add-Outcome 'note' $file
    }
    else { Add-Outcome 'fail' $script:S.PtExportFail }
}

function New-WingetOnlyImport($Path) {
    $doc = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    $keep = @($doc.Sources | Where-Object { "$($_.SourceDetails.Name)" -eq 'winget' })
    $doc.Sources = $keep
    $count = @($keep | ForEach-Object { $_.Packages }).Count
    $clean = Join-Path ([IO.Path]::GetTempPath()) ('as-import-' + [guid]::NewGuid().ToString('N') + '.json')
    [IO.File]::WriteAllText($clean, ($doc | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding $false))
    return @{ Path = $clean; Count = $count }
}

function Invoke-ProgramsImport {
    $winget = Get-WingetExe
    if (-not $winget) { Write-Host ''; Write-Host ('  ' + $script:S.PtNoWinget) -ForegroundColor Yellow; return }
    try { $dir = Get-TransferDir } catch { Write-Host ''; Write-Host ('  ' + ($script:S.PtNoDir -f (Get-ShortError $_))) -ForegroundColor Yellow; return }
    $files = @(Get-ChildItem -LiteralPath $dir -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name -Descending)
    Write-Host ''
    if ($files.Count -eq 0) { Write-Host ('  ' + ($script:S.PtNoFiles -f $dir)) -ForegroundColor Yellow; return }
    for ($i = 0; $i -lt $files.Count; $i++) { Write-Host ('  [{0,2}] {1}' -f ($i + 1), $files[$i].Name) }
    Write-Host ''
    $ans = (Read-Host ('  ' + $script:S.PtPickFile)).Trim()
    $num = 0
    if (-not ([int]::TryParse($ans, [ref]$num) -and $num -ge 1 -and $num -le $files.Count)) { return }
    try { $clean = New-WingetOnlyImport $files[$num - 1].FullName }
    catch { Write-Host ''; Write-Host ('  ' + $script:S.PtBadFile) -ForegroundColor Yellow; return }
    if ($clean.Count -eq 0) { Remove-Item -LiteralPath $clean.Path -Force -ErrorAction SilentlyContinue; Write-Host ''; Write-Host ('  ' + $script:S.PtEmpty) -ForegroundColor Yellow; return }
    Write-Host ''
    if (-not (Test-Yes (Read-Host ('  ' + ($script:S.PtImportAsk -f $clean.Count))))) { Remove-Item -LiteralPath $clean.Path -Force -ErrorAction SilentlyContinue; return }
    Start-Work
    Write-Live $script:S.PtImporting
    try {
        $rc = Invoke-Quiet $winget @('import', '--import-file', $clean.Path, '--ignore-unavailable', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
    }
    finally { Remove-Item -LiteralPath $clean.Path -Force -ErrorAction SilentlyContinue }
    if ($rc -eq 0 -or $script:WingetAlready -contains $rc) { Add-Outcome 'ok' ($script:S.PtImported -f $clean.Count) }
    elseif ($script:WingetReboot -contains $rc) { Add-Outcome 'warn' $script:S.PtReboot }
    else { Add-Outcome 'warn' $script:S.PtImportPartial }
    Show-Outcome
}

function Invoke-ProgramsTransferScreen {
    while ($true) {
        Write-Host ''
        Write-Host ('  ' + $script:S.PtTitle) -ForegroundColor Cyan
        Write-Host ''
        foreach ($l in $script:S.PtLead) { Write-Host ('  ' + $l) -ForegroundColor DarkGray }
        Write-Host ''
        Write-Host ('  ' + $script:S.PtActions)
        Write-Host ''
        $ans = (Read-Host ('  ' + $script:S.Choice)).Trim()
        if ($ans -eq '0' -or $ans -eq '') { return }
        if ($ans -eq '1') { Start-Work; Invoke-ProgramsExport; Show-Outcome; Pause-Return; continue }
        if ($ans -eq '2') { Invoke-ProgramsImport; Pause-Return; continue }
        Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow; Pause-Return
    }
}
