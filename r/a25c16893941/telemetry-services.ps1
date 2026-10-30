<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): по ЯВНОМУ выбору выключает службу DiagTrack и задачи планировщика, которые отправляют сведения
  в Microsoft, из фиксированного списка; до правки записывает снимок их состояния, возврат восстанавливает его. Окно администратора.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$script:TelService = @{ Name = 'DiagTrack' }
$script:TelTasks = @(
    @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'Consolidator' },
    @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'UsbCeip' },
    @{ Path = '\Microsoft\Windows\DiskDiagnostic\'; Name = 'Microsoft-Windows-DiskDiagnosticDataCollector' },
    @{ Path = '\Microsoft\Windows\Autochk\'; Name = 'Proxy' },
    @{ Path = '\Microsoft\Windows\Windows Error Reporting\'; Name = 'QueueReporting' }
)
$script:TelSnapId = 'telemetry-services'
$script:TelStartModes = @('Automatic', 'Manual', 'Disabled')

function Get-TelServiceMode {
    try {
        $svc = Get-CimInstance Win32_Service -Filter "Name='$($script:TelService.Name)'" -ErrorAction Stop
        if ($null -eq $svc) { return 'Missing' }
        switch ("$($svc.StartMode)") { 'Auto' { return 'Automatic' } 'Manual' { return 'Manual' } 'Disabled' { return 'Disabled' } }
    }
    catch {}
    return 'Unknown'
}

function Get-TelTaskState($Task) {
    try {
        $t = Get-ScheduledTask -TaskPath $Task.Path -TaskName $Task.Name -ErrorAction Stop
        if ("$($t.State)" -eq 'Disabled') { return 'Disabled' }
        return 'Enabled'
    }
    catch {}
    return 'Missing'
}

function Get-TelState {
    $tasks = @()
    foreach ($t in $script:TelTasks) { $tasks += @{ Path = $t.Path; Name = $t.Name; State = (Get-TelTaskState $t) } }
    return @{ Service = (Get-TelServiceMode); Tasks = $tasks }
}

function Get-TelQuoted([string]$Text) { return "'" + ($Text -replace "'", "''") + "'" }

function Get-TelCode([string]$ServiceMode, $TaskStates) {
    $lines = @('$bad = 0')
    if ($script:TelStartModes -contains $ServiceMode) {
        $n = Get-TelQuoted $script:TelService.Name
        if ($ServiceMode -eq 'Disabled') { $lines += "try { Stop-Service -Name $n -Force -ErrorAction Stop } catch {}" }
        $lines += "try { Set-Service -Name $n -StartupType $ServiceMode -ErrorAction Stop } catch { `$bad++ }"
        if ($ServiceMode -eq 'Automatic') { $lines += "try { Start-Service -Name $n -ErrorAction Stop } catch {}" }
    }
    foreach ($t in $script:TelTasks) {
        $want = $TaskStates["$($t.Path)$($t.Name)"]
        if ($want -ne 'Enabled' -and $want -ne 'Disabled') { continue }
        $verb = if ($want -eq 'Disabled') { 'Disable-ScheduledTask' } else { 'Enable-ScheduledTask' }
        $lines += "if (Get-ScheduledTask -TaskPath $(Get-TelQuoted $t.Path) -TaskName $(Get-TelQuoted $t.Name) -ErrorAction SilentlyContinue) { try { [void]($verb -TaskPath $(Get-TelQuoted $t.Path) -TaskName $(Get-TelQuoted $t.Name) -ErrorAction Stop) } catch { `$bad++ } }"
    }
    $lines += 'exit $bad'
    return ($lines -join "`n")
}

function Invoke-TelOff {
    $now = Get-TelState
    $dir = Get-PrivateCopyDir
    if (-not (Get-LatestIn $dir $script:TelSnapId)) {
        [void](Write-SnapshotFile @($now) $script:TelSnapId (Get-Date -Format 'yyyyMMdd-HHmmss') $dir)
    }
    $states = @{}
    foreach ($t in $script:TelTasks) { $states["$($t.Path)$($t.Name)"] = 'Disabled' }
    Start-Work
    Write-Live $script:S.LiveUac
    $rc = Invoke-ElevatedFixed (Get-TelCode 'Disabled' $states)
    Clear-Live
    Show-TelResult $rc $true
}

function Invoke-TelRevert {
    $path = Get-LatestIn (Get-PrivateCopyDir) $script:TelSnapId
    if (-not $path) { Start-Work; Add-Outcome 'warn' $script:S.TelNoSnap; Show-Outcome; return }
    $snap = $null
    try { $snap = @((Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json).entries)[0] } catch {}
    if ($null -eq $snap) { Start-Work; Add-Outcome 'fail' $script:S.TelBadSnap; Show-Outcome; return }
    $mode = "$($snap.Service)"
    if (-not ($script:TelStartModes -contains $mode)) { $mode = 'Automatic' }
    $states = @{}
    foreach ($t in $script:TelTasks) {
        $old = @($snap.Tasks | Where-Object { "$($_.Path)" -eq $t.Path -and "$($_.Name)" -eq $t.Name }) | Select-Object -First 1
        $want = if ($old -and "$($old.State)" -eq 'Disabled') { 'Disabled' } else { 'Enabled' }
        if ($old -and "$($old.State)" -eq 'Missing') { continue }
        $states["$($t.Path)$($t.Name)"] = $want
    }
    Start-Work
    Write-Live $script:S.LiveUac
    $rc = Invoke-ElevatedFixed (Get-TelCode $mode $states)
    Clear-Live
    if ($rc -eq 0) { Remove-SnapshotFiles $path }
    Show-TelResult $rc $false
}

function Show-TelResult([int]$Rc, [bool]$Off) {
    if ($Rc -eq -1) { Add-Outcome 'warn' $script:S.RepairDeclined }
    elseif ($Rc -eq 0) { Add-Outcome 'ok' $(if ($Off) { $script:S.TelOffDone } else { $script:S.TelRevertDone }) }
    else { Add-Outcome 'warn' ($script:S.TelPartial -f $Rc) }
    $now = Get-TelState
    Add-Outcome 'note' ($script:S.TelServiceNow -f $script:TelService.Name, $script:S.TelMode[$now.Service])
    foreach ($t in $now.Tasks) {
        if ($t.State -eq 'Missing') { continue }
        Add-Outcome 'note' ($script:S.TelTaskNow -f $t.Name, $script:S.TelMode[$t.State])
    }
    Show-Outcome
}

function Invoke-TelemetryServicesScreen {
    while ($true) {
        $now = Get-TelState
        Write-Host ''
        Write-Host ('  ' + $script:S.TelTitle) -ForegroundColor Cyan
        Write-Host ''
        foreach ($l in $script:S.TelLead) { Write-Host ('  ' + $l) -ForegroundColor DarkGray }
        Write-Host ''
        Write-Host ('    {0} - {1}' -f $script:TelService.Name, $script:S.TelMode[$now.Service])
        foreach ($t in $now.Tasks) {
            if ($t.State -eq 'Missing') { continue }
            Write-Host ('    {0} - {1}' -f $t.Name, $script:S.TelMode[$t.State])
        }
        Write-Host ''
        Write-Host ('  ' + $script:S.TelActions)
        Write-Host ''
        $ans = (Read-Host ('  ' + $script:S.Choice)).Trim()
        if ($ans -eq '0' -or $ans -eq '') { return }
        switch (Get-Key $ans) {
            'a' { if (Test-Yes (Read-Host ('  ' + $script:S.TelOffAsk))) { Invoke-TelOff } }
            'r' { Invoke-TelRevert }
            default { Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow }
        }
        Pause-Return
    }
}
