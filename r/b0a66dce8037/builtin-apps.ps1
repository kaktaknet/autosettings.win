<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): по ЯВНОМУ выбору и после вопроса с именами удаляет у ТЕКУЩЕГО пользователя встроенные
  программы Windows из фиксированного списка (Remove-AppxPackage, без -AllUsers и без provisioned); до удаления пишет снимок, возврат ставит их
  обратно из Microsoft Store через winget. Без прав администратора.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$script:BuiltinApps = @(
    @{ Pkg = 'Microsoft.BingNews';                     Store = '9WZDNCRFHVFW'; Ru = 'Новости';                   En = 'News' },
    @{ Pkg = 'Microsoft.BingWeather';                  Store = '9WZDNCRFJ3Q2'; Ru = 'Погода';                    En = 'Weather' },
    @{ Pkg = 'Microsoft.BingSearch';                   Store = '9NZBF4GT040C'; Ru = 'Поиск Bing';                En = 'Bing Search' },
    @{ Pkg = 'Microsoft.Copilot';                      Store = '9NHT9RB2F4HD'; Ru = 'Copilot';                   En = 'Copilot' },
    @{ Pkg = 'Microsoft.MicrosoftOfficeHub';           Store = '9WZDNCRD29V9'; Ru = 'Microsoft 365 (Office)';    En = 'Microsoft 365 (Office)' },
    @{ Pkg = 'Microsoft.OutlookForWindows';            Store = '9NRX63209R7B'; Ru = 'Outlook (новый)';           En = 'Outlook (new)' },
    @{ Pkg = 'MSTeams';                                Store = 'XP8BT8DW290MPQ'; Ru = 'Microsoft Teams';         En = 'Microsoft Teams' },
    @{ Pkg = 'Microsoft.Todos';                        Store = '9NBLGGH5R558'; Ru = 'Microsoft To Do';           En = 'Microsoft To Do' },
    @{ Pkg = 'Clipchamp.Clipchamp';                    Store = '9P1J8S7CCWWT'; Ru = 'Clipchamp - видеоредактор'; En = 'Clipchamp video editor' },
    @{ Pkg = 'Microsoft.PowerAutomateDesktop';         Store = '9NFTCH6J7FHV'; Ru = 'Power Automate';            En = 'Power Automate' },
    @{ Pkg = 'Microsoft.GamingApp';                    Store = '9MV0B5HZVK9Z'; Ru = 'Xbox';                      En = 'Xbox' },
    @{ Pkg = 'Microsoft.XboxGamingOverlay';            Store = '9NZKPSTSNW4P'; Ru = 'Игровая панель Xbox';       En = 'Xbox Game Bar' },
    @{ Pkg = 'Microsoft.YourPhone';                    Store = '9NMPJ99VJBWV'; Ru = 'Связь с телефоном';         En = 'Phone Link' },
    @{ Pkg = 'Microsoft.WindowsFeedbackHub';           Store = '9NBLGGH4R32N'; Ru = 'Центр отзывов';             En = 'Feedback Hub' },
    @{ Pkg = 'Microsoft.GetHelp';                      Store = '9PKDZBMV1H3T'; Ru = 'Техническая поддержка';     En = 'Get Help' },
    @{ Pkg = 'MicrosoftCorporationII.QuickAssist';     Store = '9P7BP5VNWKX5'; Ru = 'Быстрая помощь';            En = 'Quick Assist' },
    @{ Pkg = 'MicrosoftCorporationII.MicrosoftFamily'; Store = '9PDJDJS743XF'; Ru = 'Семейная безопасность';     En = 'Microsoft Family' },
    @{ Pkg = 'Microsoft.MicrosoftStickyNotes';         Store = '9NBLGGH4QGHW'; Ru = 'Записки';                   En = 'Sticky Notes' },
    @{ Pkg = 'Microsoft.WindowsAlarms';                Store = '9WZDNCRFJ3PR'; Ru = 'Часы и будильник';          En = 'Clock' },
    @{ Pkg = 'Microsoft.WindowsSoundRecorder';         Store = '9WZDNCRFHWKN'; Ru = 'Звукозапись';               En = 'Sound Recorder' },
    @{ Pkg = 'Microsoft.ZuneMusic';                    Store = '9WZDNCRFJ3PT'; Ru = 'Медиаплеер';                En = 'Media Player' },
    @{ Pkg = 'Microsoft.ZuneVideo';                    Store = '9WZDNCRFJ3P2'; Ru = 'Кино и ТВ';                 En = 'Movies & TV' }
)
$script:BuiltinSnapId = 'builtin-apps'
$script:BuiltinPresent = @()

function Get-BuiltinName($App) { if ($script:Lang -eq 'en') { return $App.En } return $App.Ru }

function Update-BuiltinPresent {
    $script:BuiltinPresent = @()
    $mine = @()
    try { $mine = @(Get-AppxPackage -ErrorAction Stop) } catch { return }
    foreach ($a in $script:BuiltinApps) {
        $p = @($mine | Where-Object { $_.Name -eq $a.Pkg -and -not $_.IsFramework -and -not $_.NonRemovable }) | Select-Object -First 1
        if ($p) { $script:BuiltinPresent += $a }
    }
}

function Get-BuiltinSnapshotNames {
    $path = Get-LatestIn (Get-PrivateCopyDir) $script:BuiltinSnapId
    if (-not $path) { return @() }
    $names = @()
    try { $names = @((Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json).entries) } catch { return @() }
    $known = @($script:BuiltinApps | ForEach-Object { $_.Pkg })
    return @($names | ForEach-Object { "$_" } | Where-Object { $known -contains $_ } | Select-Object -Unique)
}

function Save-BuiltinSnapshot($Names) {
    $dir = Get-PrivateCopyDir
    $old = Get-LatestIn $dir $script:BuiltinSnapId
    $all = @(@(Get-BuiltinSnapshotNames) + @($Names) | Select-Object -Unique)
    [void](Write-SnapshotFile $all $script:BuiltinSnapId (Get-Date -Format 'yyyyMMdd-HHmmss-fff') $dir)
    if ($old) { Remove-SnapshotFiles $old }
}

function Invoke-BuiltinRemove($Apps) {
    Write-Host ''
    foreach ($a in $Apps) { Write-Host ('    ' + (Get-BuiltinName $a)) }
    Write-Host ''
    Write-Host ('  ' + $script:S.BuiltinDataWarn) -ForegroundColor Yellow
    if (-not (Test-Yes (Read-Host ('  ' + ($script:S.BuiltinRemoveAsk -f @($Apps).Count))))) { return }
    Save-BuiltinSnapshot @($Apps | ForEach-Object { $_.Pkg })
    Start-Work
    foreach ($a in $Apps) {
        $name = Get-BuiltinName $a
        Write-Live $name
        $ok = $true
        try {
            foreach ($p in @(Get-AppxPackage -Name $a.Pkg -ErrorAction Stop | Where-Object { -not $_.IsFramework -and -not $_.NonRemovable })) {
                Remove-AppxPackage -Package $p.PackageFullName -ErrorAction Stop
            }
        }
        catch { $ok = $false }
        if ($ok) { Add-Outcome 'ok' ($script:S.BuiltinRemoved -f $name) } else { Add-Outcome 'fail' ($script:S.BuiltinRemoveFail -f $name) }
    }
    Clear-Live
    Add-Outcome 'note' $script:S.BuiltinHowBack
    Show-Outcome
}

function Invoke-BuiltinRestore {
    $names = @(Get-BuiltinSnapshotNames)
    if ($names.Count -eq 0) { Start-Work; Add-Outcome 'warn' $script:S.BuiltinNoSnap; Show-Outcome; return }
    $winget = Get-WingetExe
    if (-not $winget) { Start-Work; Add-Outcome 'fail' $script:S.BuiltinNoWinget; Show-Outcome; return }
    $apps = @($script:BuiltinApps | Where-Object { $names -contains $_.Pkg })
    Write-Host ''
    foreach ($a in $apps) { Write-Host ('    ' + (Get-BuiltinName $a)) }
    Write-Host ''
    if (-not (Test-Yes (Read-Host ('  ' + ($script:S.BuiltinRestoreAsk -f $apps.Count))))) { return }
    Start-Work
    $left = @()
    foreach ($a in $apps) {
        $name = Get-BuiltinName $a
        Write-Live $name
        $rc = Invoke-Quiet $winget @('install', '-e', '--id', $a.Store, '--source', 'msstore', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
        if ($rc -eq 0 -or $script:WingetAlready -contains $rc) { Add-Outcome 'ok' ($script:S.BuiltinRestored -f $name) }
        else { $left += $a.Pkg; Add-Outcome 'fail' ($script:S.BuiltinRestoreFail -f $name, $rc) }
    }
    Clear-Live
    $dir = Get-PrivateCopyDir
    $old = Get-LatestIn $dir $script:BuiltinSnapId
    if ($left.Count -gt 0) { [void](Write-SnapshotFile $left $script:BuiltinSnapId (Get-Date -Format 'yyyyMMdd-HHmmss-fff') $dir) }
    if ($old) { Remove-SnapshotFiles $old }
    Show-Outcome
}

function Invoke-BuiltinAppsScreen {
    $stale = $true
    while ($true) {
        if ($stale) { Update-BuiltinPresent; $stale = $false }
        $list = @($script:BuiltinPresent)
        Write-Host ''
        Write-Host ('  ' + $script:S.BuiltinTitle) -ForegroundColor Cyan
        Write-Host ''
        foreach ($l in $script:S.BuiltinLead) { Write-Host ('  ' + $l) -ForegroundColor DarkGray }
        Write-Host ''
        if ($list.Count -eq 0) { Write-Host ('  ' + $script:S.BuiltinNone) -ForegroundColor DarkGray }
        for ($i = 0; $i -lt $list.Count; $i++) { Write-Host ('  [{0,2}] {1}' -f ($i + 1), (Get-BuiltinName $list[$i])) }
        $back = @(Get-BuiltinSnapshotNames).Count
        if ($back -gt 0) { Write-Host ''; Write-Host ('  ' + ($script:S.BuiltinCanBack -f $back)) -ForegroundColor DarkGray }
        Write-Host ''
        Write-Host ('  ' + $script:S.BuiltinActions)
        Write-Host ''
        $ans = (Read-Host ('  ' + $script:S.Choice)).Trim()
        if ($ans -eq '0' -or $ans -eq '') { return }
        if ((Get-Key $ans) -eq 'r') { Invoke-BuiltinRestore; $stale = $true; Pause-Return; continue }
        $sel = @()
        foreach ($tok in ($ans -split '[,\s]+' | Where-Object { $_ -ne '' })) {
            $num = 0
            if ([int]::TryParse($tok, [ref]$num) -and $num -ge 1 -and $num -le $list.Count -and -not (@($sel | ForEach-Object { $_.Pkg }) -contains $list[$num - 1].Pkg)) { $sel += $list[$num - 1] }
        }
        if ($sel.Count -eq 0) { Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow }
        else { Invoke-BuiltinRemove $sel; $stale = $true }
        Pause-Return
    }
}
