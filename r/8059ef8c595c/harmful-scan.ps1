<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): ищет правки чужих «оптимизаторов», которые ломают обновления, магазин и защиту
  Windows, и показывает отчёт. По ЯВНОМУ выбору номера удаляет только найденные значения политик из фиксированного списка (удаление
  возвращает поведение Windows по умолчанию); выключенным службам из фиксированного списка возвращает тип запуска Windows по
  умолчанию; строки файла hosts, закрывающие адреса Microsoft, закомментирует меткой (копия файла рядом). До изменения пишет
  снимок, возврат восстанавливает прежнее. UAC, защиты процессора и IPv6 - только отчёт. На машине в домене, под управлением
  MDM организации или с WSUS - только отчёт.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$script:HtSnapId = 'harmful-tweaks'
$script:HtTypes = @('DWord')
$script:HtPolicies = @(
    @{ Id = 'wu-noauto';     Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'NoAutoUpdate'; Bad = 1 },
    @{ Id = 'wu-access';     Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'DisableWindowsUpdateAccess'; Bad = 1 },
    @{ Id = 'wu-ux';         Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'SetDisableUXWUAccess'; Bad = 1 },
    @{ Id = 'wu-internet';   Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'DoNotConnectToWindowsUpdateInternetLocations'; Bad = 1 },
    @{ Id = 'do-bypass';     Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name = 'DODownloadMode'; Bad = 100 },
    @{ Id = 'store-off';     Path = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore'; Name = 'RemoveWindowsStore'; Bad = 1 },
    @{ Id = 'store-off-me';  Path = 'HKCU:\Software\Policies\Microsoft\WindowsStore'; Name = 'RemoveWindowsStore'; Bad = 1 },
    @{ Id = 'store-noupd';   Path = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore'; Name = 'AutoDownload'; Bad = 2 },
    @{ Id = 'defender-off';  Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'DisableAntiSpyware'; Bad = 1 },
    @{ Id = 'smartscreen';   Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'EnableSmartScreen'; Bad = 0 },
    @{ Id = 'fw-domain';     Path = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile'; Name = 'EnableFirewall'; Bad = 0 },
    @{ Id = 'fw-private';    Path = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\StandardProfile'; Name = 'EnableFirewall'; Bad = 0 },
    @{ Id = 'fw-public';     Path = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\PublicProfile'; Name = 'EnableFirewall'; Bad = 0 },
    @{ Id = 'restore-off';   Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore'; Name = 'DisableSR'; Bad = 1 }
)
$script:HtServices = @(
    @{ Name = 'wuauserv'; Default = 3 }, @{ Name = 'UsoSvc'; Default = 3 }, @{ Name = 'BITS'; Default = 3 },
    @{ Name = 'WaaSMedicSvc'; Default = 3 }, @{ Name = 'CryptSvc'; Default = 2 }, @{ Name = 'TrustedInstaller'; Default = 3 },
    @{ Name = 'InstallService'; Default = 3 }, @{ Name = 'AppXSvc'; Default = 3 }, @{ Name = 'ClipSVC'; Default = 3 },
    @{ Name = 'WinDefend'; Default = 2 }, @{ Name = 'SecurityHealthService'; Default = 3 }, @{ Name = 'wscsvc'; Default = 2 },
    @{ Name = 'mpssvc'; Default = 2 }, @{ Name = 'BFE'; Default = 2 }, @{ Name = 'Dnscache'; Default = 2 },
    @{ Name = 'NlaSvc'; Default = 2 }, @{ Name = 'W32Time'; Default = 3 }, @{ Name = 'WSearch'; Default = 2 },
    @{ Name = 'SysMain'; Default = 2 }, @{ Name = 'WpnService'; Default = 2 }
)
$script:HtStartNames = @{ 2 = 'Automatic'; 3 = 'Manual'; 4 = 'Disabled' }
$script:HtHostsRx = '^\s*(0\.0\.0\.0|127\.0\.0\.1)\s+\S*(microsoft|windowsupdate|msftconnecttest|msftncsi|windows\.com|live\.com)'
$script:HtHostsMark = '# autosettings-off '

function Get-HtValue($Path, $Name) {
    try {
        if (-not (Test-Path -LiteralPath $Path)) { return $null }
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        $v = $item.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ($null -eq $v) { return $null }
        return @{ Type = "$($item.GetValueKind($Name))"; Data = $v }
    }
    catch { return $null }
}

function Test-HtOurs($Row) {
    foreach ($s in @($data.settings)) {
        if ("$($s.path)" -eq $Row.Path -and "$($s.name)" -eq $Row.Name -and "$($s.value)" -eq "$($Row.Bad)") { return $true }
    }
    return $false
}

function Get-HtManaged {
    $why = @()
    try { if ((Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).PartOfDomain) { $why += 'domain' } } catch {}
    $acc = 'HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts'
    if (Test-Path -LiteralPath $acc) {
        foreach ($k in @(Get-ChildItem -LiteralPath $acc -ErrorAction SilentlyContinue)) {
            $uid = "$((Get-ItemProperty -LiteralPath $k.PSPath -Name 'AcctUId' -ErrorAction SilentlyContinue).AcctUId)"
            if (-not ($k.PSChildName -eq 'FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF' -and $uid -eq ('0x' + ('0' * 72)))) { $why += 'mdm'; break }
        }
    }
    $wsus = Get-HtValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'WUServer'
    if ($wsus -and "$($wsus.Data)" -match '^https?://[^\s/]+') { $why += 'wsus' }
    return $why
}

function Find-HtPolicies {
    $out = @()
    foreach ($r in $script:HtPolicies) {
        if (Test-HtOurs $r) { continue }
        $v = Get-HtValue $r.Path $r.Name
        if ($v -and $v.Type -eq 'DWord' -and [int64]$v.Data -eq [int64]$r.Bad) { $out += $r }
    }
    foreach ($s in $script:HtServices) {
        $v = Get-HtValue ('HKLM:\SYSTEM\CurrentControlSet\Services\' + $s.Name) 'Start'
        if ($v -and [int64]$v.Data -eq 4) { $out += @{ Id = ('svc-' + $s.Name); Svc = $s } }
    }
    $n = @(Get-HtHostsLines | Where-Object { $_ -match $script:HtHostsRx }).Count
    if ($n -gt 0) { $out += @{ Id = 'hosts'; Hosts = $n } }
    return $out
}

function Get-HtHostsPath { return (Join-Path (Join-Path (Join-Path ([Environment]::SystemDirectory) 'drivers') 'etc') 'hosts') }

function Get-HtHostsLines {
    try { return @(Get-Content -LiteralPath (Get-HtHostsPath) -ErrorAction Stop) } catch { return @() }
}

function Get-HtLabel($Row) {
    if ($Row.Svc) { return ($script:S.HtServiceRow -f $Row.Svc.Name, $script:S.HtStartWords[[int]$Row.Svc.Default]) }
    if ($Row.Hosts) { return ($script:S.HtHostsRow -f $Row.Hosts) }
    return $script:S.HtRows[$Row.Id]
}

function Find-HtReport {
    $out = @()
    $lua = Get-HtValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'EnableLUA'
    if ($lua -and [int64]$lua.Data -eq 0) { $out += $script:S.HtUacOff }
    $fso = Get-HtValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' 'FeatureSettingsOverride'
    if ($fso -and [int64]$fso.Data -eq 3) { $out += $script:S.HtMitigationsOff }
    $v6 = Get-HtValue 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' 'DisabledComponents'
    if ($v6 -and ([int64]$v6.Data -band 0xFF) -eq 0xFF) { $out += $script:S.HtIpv6Off }
    return $out
}

function Get-HtQuoted([string]$Text) { return "'" + ($Text -replace "'", "''") + "'" }

function Get-HtServiceLine($Svc, [int]$Start) {
    $name = Get-HtQuoted $Svc.Name
    $key = Get-HtQuoted ('HKLM:\SYSTEM\CurrentControlSet\Services\' + $Svc.Name)
    return "try { Set-Service -Name $name -StartupType $($script:HtStartNames[$Start]) -ErrorAction Stop } catch { try { Set-ItemProperty -LiteralPath $key -Name 'Start' -Value $Start -Type DWord -ErrorAction Stop } catch { `$bad++ } }"
}

function Get-HtHostsCode([bool]$Mark) {
    $h = '$h = Join-Path (Join-Path (Join-Path ([Environment]::SystemDirectory) ''drivers'') ''etc'') ''hosts'''
    $m = Get-HtQuoted $script:HtHostsMark
    if ($Mark) {
        $rx = Get-HtQuoted $script:HtHostsRx
        return @($h, "try { Copy-Item -LiteralPath `$h -Destination (`$h + '.autosettings.bak') -Force -ErrorAction Stop; `$l = [IO.File]::ReadAllLines(`$h); [IO.File]::WriteAllLines(`$h, [string[]]@(`$l | ForEach-Object { if (`$_ -match $rx) { $m + `$_ } else { `$_ } })) } catch { `$bad++ }")
    }
    return @($h, "try { `$l = [IO.File]::ReadAllLines(`$h); [IO.File]::WriteAllLines(`$h, [string[]]@(`$l | ForEach-Object { if (`$_.StartsWith($m)) { `$_.Substring($m.Length) } else { `$_ } })) } catch { `$bad++ }")
}

function Get-HtRemoveCode($Rows) {
    $lines = @('$bad = 0')
    foreach ($r in $Rows) {
        if ($r.Svc) { $lines += Get-HtServiceLine $r.Svc ([int]$r.Svc.Default) }
        elseif ($r.Hosts) { $lines += Get-HtHostsCode $true }
        else { $lines += "try { Remove-ItemProperty -LiteralPath $(Get-HtQuoted $r.Path) -Name $(Get-HtQuoted $r.Name) -ErrorAction Stop } catch { `$bad++ }" }
    }
    $lines += 'exit $bad'
    return ($lines -join "`n")
}

function Get-HtRestoreCode($Pairs) {
    $lines = @('$bad = 0')
    foreach ($p in $Pairs) {
        if ($p.Row.Svc) { $lines += Get-HtServiceLine $p.Row.Svc ([int]$p.Data); continue }
        if ($p.Row.Hosts) { $lines += Get-HtHostsCode $false; continue }
        $path = Get-HtQuoted $p.Row.Path
        $val = [string][int64]$p.Data
        $lines += "try { if (-not (Test-Path -LiteralPath $path)) { [void](New-Item -Path $path -Force) }; [void](New-ItemProperty -LiteralPath $path -Name $(Get-HtQuoted $p.Row.Name) -PropertyType DWord -Value $val -Force -ErrorAction Stop) } catch { `$bad++ }"
    }
    $lines += 'exit $bad'
    return ($lines -join "`n")
}

function Invoke-HtRemove($Rows) {
    $dir = Get-PrivateCopyDir
    $entries = @()
    foreach ($r in $Rows) {
        if ($r.Svc) { $entries += @{ Id = $r.Id; Type = 'Service'; Data = '4' }; continue }
        if ($r.Hosts) { $entries += @{ Id = 'hosts'; Type = 'Hosts'; Data = "$($r.Hosts)" }; continue }
        $v = Get-HtValue $r.Path $r.Name
        if ($v) { $entries += @{ Id = $r.Id; Type = $v.Type; Data = "$($v.Data)" } }
    }
    $prev = Get-LatestIn $dir $script:HtSnapId
    if ($prev) {
        try {
            $have = @($entries | ForEach-Object { $_.Id })
            foreach ($e in @((Get-Content -LiteralPath $prev -Raw -Encoding UTF8 | ConvertFrom-Json).entries)) {
                if ($have -notcontains "$($e.Id)") { $entries += @{ Id = "$($e.Id)"; Type = "$($e.Type)"; Data = "$($e.Data)" } }
            }
        }
        catch {}
    }
    [void](Write-SnapshotFile $entries $script:HtSnapId (Get-Date -Format 'yyyyMMdd-HHmmss') $dir)
    if ($prev) { Remove-SnapshotFiles $prev }
    Start-Work
    $failed = 0
    foreach ($r in @($Rows | Where-Object { "$($_.Path)" -like 'HKCU:*' })) {
        try { Remove-ItemProperty -LiteralPath $r.Path -Name $r.Name -ErrorAction Stop } catch { $failed++ }
    }
    $machine = @($Rows | Where-Object { "$($_.Path)" -notlike 'HKCU:*' })
    $rc = 0
    if ($machine.Count -gt 0) {
        Write-Live $script:S.LiveUac
        $rc = Invoke-ElevatedFixed (Get-HtRemoveCode $machine)
        Clear-Live
    }
    if ($rc -eq -1) { Add-Outcome 'warn' $script:S.RepairDeclined }
    elseif ($rc -eq 0 -and $failed -eq 0) { Add-Outcome 'ok' $script:S.HtRemoved; Add-Outcome 'note' $script:S.HtRestartHint }
    else { Add-Outcome 'warn' ($script:S.HtPartial -f ($failed + [Math]::Max($rc, 0))) }
    Show-Outcome
}

function Test-HtEntry($E) {
    $id = "$($E.Id)"
    if ($id -eq 'hosts') {
        if ("$($E.Type)" -ne 'Hosts') { return $null }
        return @{ Row = @{ Id = 'hosts'; Hosts = 1 }; Type = 'Hosts'; Data = 0 }
    }
    if ($id.StartsWith('svc-')) {
        $svc = @($script:HtServices | Where-Object { ('svc-' + $_.Name) -eq $id }) | Select-Object -First 1
        $n = 0
        if (-not $svc -or "$($E.Type)" -ne 'Service' -or -not [int]::TryParse("$($E.Data)", [ref]$n) -or -not $script:HtStartNames.ContainsKey($n)) { return $null }
        return @{ Row = @{ Id = $id; Svc = $svc }; Type = 'Service'; Data = $n }
    }
    $row = @($script:HtPolicies | Where-Object { $_.Id -eq $id }) | Select-Object -First 1
    if (-not $row) { return $null }
    $t = "$($E.Type)"
    if (-not ($script:HtTypes -contains $t)) { return $null }
    $d = "$($E.Data)"
    $n = 0L
    if (-not [int64]::TryParse($d, [ref]$n) -or $n -lt 0 -or $n -gt 2147483647) { return $null }
    return @{ Row = $row; Type = 'DWord'; Data = $n }
}

function Invoke-HtRevert {
    $path = Get-LatestIn (Get-PrivateCopyDir) $script:HtSnapId
    if (-not $path) { Start-Work; Add-Outcome 'warn' $script:S.HtNoSnap; Show-Outcome; return }
    $entries = $null
    try { $entries = @((Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json).entries) } catch {}
    if ($null -eq $entries) { Start-Work; Add-Outcome 'fail' $script:S.HtBadSnap; Show-Outcome; return }
    $pairs = @()
    $refused = 0
    foreach ($e in $entries) {
        $p = Test-HtEntry $e
        if ($p) { $pairs += $p } else { $refused++ }
    }
    Start-Work
    $failed = 0
    foreach ($p in @($pairs | Where-Object { "$($_.Row.Path)" -like 'HKCU:*' })) {
        try {
            if (-not (Test-Path -LiteralPath $p.Row.Path)) { [void](New-Item -Path $p.Row.Path -Force) }
            [void](New-ItemProperty -LiteralPath $p.Row.Path -Name $p.Row.Name -PropertyType DWord -Value ([int]$p.Data) -Force -ErrorAction Stop)
        }
        catch { $failed++ }
    }
    $machine = @($pairs | Where-Object { "$($_.Row.Path)" -notlike 'HKCU:*' })
    $rc = 0
    if ($machine.Count -gt 0) {
        Write-Live $script:S.LiveUac
        $rc = Invoke-ElevatedFixed (Get-HtRestoreCode $machine)
        Clear-Live
    }
    if ($rc -ne 0) { $failed++ }
    if ($failed -eq 0 -and $refused -eq 0) { Remove-SnapshotFiles $path; Add-Outcome 'ok' $script:S.HtRestored }
    elseif ($rc -eq -1) { Add-Outcome 'warn' $script:S.RepairDeclined }
    else { Add-Outcome 'warn' ($script:S.HtPartial -f ($failed + $refused)) }
    Show-Outcome
}

function Invoke-HarmfulScanScreen {
    while ($true) {
        Clear-Host
        Write-Host ''
        Write-Host ('  ' + $script:S.HtTitle) -ForegroundColor Cyan
        Write-Host ''
        foreach ($l in $script:S.HtLead) { Write-Host ('  ' + $l) -ForegroundColor DarkGray }
        Write-Host ''
        $managed = @(Get-HtManaged)
        $found = @(Find-HtPolicies)
        $report = @(Find-HtReport)
        if ($found.Count -eq 0 -and $report.Count -eq 0) { Write-Host ('  ' + $script:S.HtClean) -ForegroundColor Green }
        for ($i = 0; $i -lt $found.Count; $i++) {
            Write-Host ('  [{0}] {1}' -f ($i + 1), (Get-HtLabel $found[$i]))
        }
        if ($report.Count -gt 0) {
            Write-Host ''
            Write-Host ('  ' + $script:S.HtReportTitle) -ForegroundColor Yellow
            foreach ($l in $report) { Write-Host ('      ' + $l) }
        }
        Write-Host ''
        if ($managed.Count -gt 0) {
            Write-Host ('  ' + ($script:S.HtManaged -f (($managed | ForEach-Object { $script:S.HtManagedWhy[$_] }) -join ', '))) -ForegroundColor Yellow
            Write-Host ('  ' + $script:S.HtActionsManaged)
        }
        elseif ($found.Count -gt 0) { Write-Host ('  ' + $script:S.HtActions) }
        else { Write-Host ('  ' + $script:S.HtActionsNone) }
        Write-Host ''
        $ans = (Read-Host ('  ' + $script:S.Choice)).Trim()
        if ($ans -eq '0' -or $ans -eq '') { return }
        if ((Get-Key $ans) -eq 'r') { Invoke-HtRevert; Pause-Return; continue }
        if ($managed.Count -gt 0 -or $found.Count -eq 0) { Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow; Pause-Return; continue }
        $picked = @(); $bad = $false
        foreach ($tok in @($ans -split '[,\s]+' | Where-Object { $_ -ne '' })) {
            $num = 0
            if ([int]::TryParse($tok, [ref]$num) -and $num -ge 1 -and $num -le $found.Count) { $picked += $found[$num - 1] }
            else { $bad = $true }
        }
        if ($bad -or $picked.Count -eq 0) { Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow; Pause-Return; continue }
        Write-Host ''
        foreach ($p in $picked) { Write-Host ('    ' + (Get-HtLabel $p)) }
        if (Test-Yes (Read-Host ('  ' + $script:S.HtAsk))) { Invoke-HtRemove $picked }
        Pause-Return
    }
}
