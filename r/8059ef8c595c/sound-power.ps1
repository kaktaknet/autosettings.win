<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): по ЯВНОМУ выбору выключает системные звуки текущего пользователя (схема «Без звуков»:
  значения .Current в HKCU\AppEvents) и включает встроенную схему питания «Высокая производительность» только на компьютере без
  батареи и без Modern Standby. Если производитель убрал эту схему из списка, создаёт её копию (powercfg /duplicatescheme) и
  включает копию. До правки записывает снимок (звуки - каждое значение, питание - GUID прежней схемы и GUID созданной копии),
  возврат восстанавливает прежнюю схему и удаляет только созданную копию. Прав администратора не просит.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$script:SpSoundSnapId = 'sound-scheme'
$script:SpPowerSnapId = 'power-scheme'
$script:SpAppsSub = 'AppEvents\Schemes\Apps'
$script:SpSchemesSub = 'AppEvents\Schemes'
$script:SpSoundPathRx = '^AppEvents\\Schemes\\Apps\\[^\\]+\\[^\\]+\\\.Current$'
$script:SpKinds = @('String', 'ExpandString', 'Missing')
$script:SpHighPerf = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
$script:SpGuidRx = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
$script:SpBuiltIn = @('381b4222-f694-41f0-9685-ff5bb260df2e', '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c', 'a1841308-3541-4fab-bc81-f71556f20b4a', 'e9a42b02-d5df-448d-aa00-03f14749eb61')

function Get-SpDefault($Sub) {
    $k = $null
    try { $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($Sub) } catch {}
    if ($null -eq $k) { return $null }
    try {
        $v = $k.GetValue('', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ($null -eq $v) { return @{ Sub = $Sub; Kind = 'Missing'; Data = '' } }
        return @{ Sub = $Sub; Kind = "$($k.GetValueKind(''))"; Data = "$v" }
    }
    finally { $k.Close() }
}

function Set-SpDefault($Sub, $Kind, $Data) {
    $k = $null
    try { $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($Sub, $true) } catch {}
    if ($null -eq $k) { return $false }
    try {
        if ($Kind -eq 'Missing') { $k.DeleteValue('', $false) }
        else { $k.SetValue('', [string]$Data, [Microsoft.Win32.RegistryValueKind]$Kind) }
        return $true
    }
    catch { return $false }
    finally { $k.Close() }
}

function Get-SpSoundEntries {
    $out = @()
    $apps = $null
    try { $apps = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:SpAppsSub) } catch {}
    if ($null -eq $apps) { return $out }
    try {
        foreach ($app in $apps.GetSubKeyNames()) {
            $ak = $apps.OpenSubKey($app)
            if ($null -eq $ak) { continue }
            try {
                foreach ($ev in $ak.GetSubKeyNames()) {
                    $e = Get-SpDefault ($script:SpAppsSub + '\' + $app + '\' + $ev + '\.Current')
                    if ($null -ne $e) { $out += $e }
                }
            }
            finally { $ak.Close() }
        }
    }
    finally { $apps.Close() }
    return $out
}

function Get-SpSoundsOn { return @(Get-SpSoundEntries | Where-Object { $_.Kind -ne 'Missing' -and $_.Data -ne '' }).Count }

function Invoke-SpSoundsOff {
    $dir = Get-PrivateCopyDir
    if (-not (Get-LatestIn $dir $script:SpSoundSnapId)) {
        $entries = @(Get-SpSoundEntries)
        $scheme = Get-SpDefault $script:SpSchemesSub
        if ($null -ne $scheme) { $entries += $scheme }
        [void](Write-SnapshotFile $entries $script:SpSoundSnapId (Get-Date -Format 'yyyyMMdd-HHmmss') $dir)
    }
    Start-Work
    Write-Live $script:S.SpSoundName
    $failed = 0
    foreach ($e in @(Get-SpSoundEntries)) {
        if ($e.Kind -eq 'Missing' -or $e.Data -eq '') { continue }
        if (-not (Set-SpDefault $e.Sub $e.Kind '')) { $failed++ }
    }
    [void](Set-SpDefault $script:SpSchemesSub 'String' '.None')
    Clear-Live
    if ($failed -eq 0) { Add-Outcome 'ok' $script:S.SpSoundDone } else { Add-Outcome 'warn' ($script:S.SpPartial -f $failed) }
    Show-Outcome
}

function Test-SpSoundEntry($E) {
    $sub = "$($E.Sub)"
    if (-not ($script:SpKinds -contains "$($E.Kind)")) { return $false }
    return ($sub -match $script:SpSoundPathRx -or $sub -eq $script:SpSchemesSub)
}

function Invoke-SpSoundRevert {
    $path = Get-LatestIn (Get-PrivateCopyDir) $script:SpSoundSnapId
    if (-not $path) { Start-Work; Add-Outcome 'warn' $script:S.SpNoSnap; Show-Outcome; return }
    $entries = $null
    try { $entries = @((Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json).entries) } catch {}
    if ($null -eq $entries) { Start-Work; Add-Outcome 'fail' $script:S.SpBadSnap; Show-Outcome; return }
    Start-Work
    Write-Live $script:S.SpSoundName
    $failed = 0
    $refused = 0
    foreach ($e in $entries) {
        if (-not (Test-SpSoundEntry $e)) { $refused++; continue }
        if (-not (Set-SpDefault "$($e.Sub)" "$($e.Kind)" "$($e.Data)")) { $failed++ }
    }
    Clear-Live
    if ($failed -eq 0 -and $refused -eq 0) { Remove-SnapshotFiles $path; Add-Outcome 'ok' $script:S.SpSoundBack }
    else { Add-Outcome 'warn' ($script:S.SpPartial -f ($failed + $refused)) }
    Show-Outcome
}

function Get-SpPowerCaps {
    try {
        if (-not ('AutoSettings.PowrProf' -as [type])) {
            Add-Type -Namespace AutoSettings -Name PowrProf -MemberDefinition '[DllImport("powrprof.dll")] public static extern bool GetPwrCapabilities(byte[] caps);'
        }
        $b = New-Object byte[] 76
        if (-not [AutoSettings.PowrProf]::GetPwrCapabilities($b)) { return $null }
        return @{ ModernStandby = ($b[20] -ne 0); Battery = ($b[30] -ne 0) }
    }
    catch { return $null }
}

function Get-SpPowercfg {
    $sys = [Environment]::SystemDirectory
    if (-not $sys) { return $null }
    return (Join-Path $sys 'powercfg.exe')
}

function Get-SpSchemes {
    $exe = Get-SpPowercfg
    if (-not $exe -or -not (Test-Path -LiteralPath $exe)) { return @() }
    $text = (& $exe /list 2>$null) -join "`n"
    return @([regex]::Matches($text, $script:SpGuidRx) | ForEach-Object { $_.Value.ToLowerInvariant() })
}

function Get-SpActiveScheme {
    $exe = Get-SpPowercfg
    if (-not $exe -or -not (Test-Path -LiteralPath $exe)) { return $null }
    $m = [regex]::Match(((& $exe /getactivescheme 2>$null) -join ' '), $script:SpGuidRx)
    if ($m.Success) { return $m.Value.ToLowerInvariant() }
    return $null
}

function Test-SpPowerManaged {
    $p = 'HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings'
    if (-not (Test-Path -LiteralPath $p)) { return $false }
    return ($null -ne (Get-ItemProperty -LiteralPath $p -Name 'ActivePowerScheme' -ErrorAction SilentlyContinue))
}

function Read-SpPowerSnap($Path) {
    if (-not $Path) { return $null }
    try {
        $e = @((Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json).entries)[0]
        return @{ Active = "$($e.Active)".ToLowerInvariant(); Created = "$($e.Created)".ToLowerInvariant() }
    }
    catch { return $null }
}

function Test-SpGuid($Guid) {
    return ("$Guid" -match ('^' + $script:SpGuidRx + '$'))
}

function Get-SpOwnCopy($Snap, $Schemes) {
    if ($null -eq $Snap -or -not (Test-SpGuid $Snap.Created)) { return $null }
    if ($script:SpBuiltIn -contains $Snap.Created) { return $null }
    if (-not (@($Schemes) -contains $Snap.Created)) { return $null }
    return $Snap.Created
}

function Get-SpTarget {
    $schemes = @(Get-SpSchemes)
    if ($schemes -contains $script:SpHighPerf) { return $script:SpHighPerf }
    return (Get-SpOwnCopy (Read-SpPowerSnap (Get-LatestIn (Get-PrivateCopyDir) $script:SpPowerSnapId)) $schemes)
}

function Get-SpPowerFit {
    $caps = Get-SpPowerCaps
    if ($null -eq $caps) { return 'unknown' }
    if ($caps.ModernStandby -or $caps.Battery) { return 'mobile' }
    if (Test-SpPowerManaged) { return 'managed' }
    if (-not (Get-SpTarget)) { return 'create' }
    return 'ok'
}

function New-SpHighCopy {
    $exe = Get-SpPowercfg
    if (-not $exe -or -not (Test-Path -LiteralPath $exe)) { return $null }
    $before = @(Get-SpSchemes)
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $text = (& $exe /duplicatescheme $script:SpHighPerf 2>&1) -join ' ' } catch { return $null } finally { $ErrorActionPreference = $old }
    $guid = $null
    foreach ($m in [regex]::Matches($text, $script:SpGuidRx)) {
        $g = $m.Value.ToLowerInvariant()
        if ($g -ne $script:SpHighPerf -and -not ($before -contains $g)) { $guid = $g }
    }
    if ($guid -and (@(Get-SpSchemes) -contains $guid)) { return $guid }
    return $null
}

function Remove-SpScheme($Guid) {
    $exe = Get-SpPowercfg
    if (-not $exe) { return $false }
    [void](Invoke-Quiet $exe @('/delete', $Guid))
    return (-not (@(Get-SpSchemes) -contains $Guid))
}

function Set-SpActive($Guid) {
    $exe = Get-SpPowercfg
    if (-not $exe) { return $false }
    $rc = Invoke-Quiet $exe @('/setactive', $Guid)
    return ($rc -eq 0 -and (Get-SpActiveScheme) -eq $Guid)
}

function Invoke-SpPowerHigh {
    $fit = Get-SpPowerFit
    if ($fit -ne 'ok' -and $fit -ne 'create') { Start-Work; Add-Outcome 'warn' $script:S.SpPowerWhy[$fit]; Show-Outcome; return }
    $target = Get-SpTarget
    $now = Get-SpActiveScheme
    if ($target -and $now -eq $target) { Start-Work; Add-Outcome 'ok' $script:S.SpPowerAlready; Show-Outcome; return }
    $dir = Get-PrivateCopyDir
    $snapPath = Get-LatestIn $dir $script:SpPowerSnapId
    $snap = Read-SpPowerSnap $snapPath
    Start-Work
    Write-Live $script:S.SpPowerName
    if (-not $target) {
        $target = New-SpHighCopy
        if (-not $target) { Clear-Live; Add-Outcome 'warn' $script:S.SpPowerWhy['missing']; Show-Outcome; return }
        $active = $now
        if ($snap -and (Test-SpGuid $snap.Active)) { $active = $snap.Active }
        try { $new = Write-SnapshotFile @(@{ Active = $active; Created = $target }) $script:SpPowerSnapId (Get-Date -Format 'yyyyMMdd-HHmmss') $dir }
        catch { [void](Remove-SpScheme $target); Clear-Live; Add-Outcome 'fail' $script:S.SpPowerFail; Show-Outcome; return }
        if ($snapPath -and $new -ne $snapPath) { Remove-SnapshotFiles $snapPath }
        Add-Outcome 'ok' $script:S.SpPowerCreated
    }
    elseif ($now -and -not $snapPath) {
        [void](Write-SnapshotFile @(@{ Active = $now }) $script:SpPowerSnapId (Get-Date -Format 'yyyyMMdd-HHmmss') $dir)
    }
    $ok = Set-SpActive $target
    Clear-Live
    if ($ok) { Add-Outcome 'ok' $script:S.SpPowerDone } else { Add-Outcome 'fail' $script:S.SpPowerFail }
    Show-Outcome
}

function Invoke-SpPowerRevert {
    $path = Get-LatestIn (Get-PrivateCopyDir) $script:SpPowerSnapId
    if (-not $path) { Start-Work; Add-Outcome 'warn' $script:S.SpNoSnap; Show-Outcome; return }
    $snap = Read-SpPowerSnap $path
    $failed = 0
    $refused = 0
    $schemes = @(Get-SpSchemes)
    if ($null -eq $snap -or -not (Test-SpGuid $snap.Active) -or -not ($schemes -contains $snap.Active)) { $refused++ }
    else {
        Start-Work
        Write-Live $script:S.SpPowerName
        if (-not (Set-SpActive $snap.Active)) { $failed++ }
        else {
            $own = Get-SpOwnCopy $snap $schemes
            if ($own -and $own -ne $snap.Active -and -not (Remove-SpScheme $own)) { $failed++ }
        }
        Clear-Live
    }
    if ($failed -eq 0 -and $refused -eq 0) { Remove-SnapshotFiles $path; Add-Outcome 'ok' $script:S.SpPowerBack }
    elseif ($refused -gt 0) { Start-Work; Add-Outcome 'fail' $script:S.SpBadSnap }
    else { Add-Outcome 'fail' $script:S.SpPowerFail }
    Show-Outcome
}

function Invoke-SoundPowerScreen {
    while ($true) {
        $fit = Get-SpPowerFit
        Write-Host ''
        Write-Host ('  ' + $script:S.SpTitle) -ForegroundColor Cyan
        Write-Host ''
        foreach ($l in $script:S.SpLead) { Write-Host ('  ' + $l) -ForegroundColor DarkGray }
        Write-Host ''
        Write-Host ('  [1] ' + ($script:S.SpSoundItem -f (Get-SpSoundsOn)))
        Write-Host ('  [2] ' + $script:S.SpSoundRevertItem)
        if ($fit -eq 'ok' -or $fit -eq 'create') {
            Write-Host ('  [3] ' + $script:S.SpPowerItem)
            if ($fit -eq 'create') { Write-Host ('      ' + $script:S.SpPowerCreateNote) -ForegroundColor DarkGray }
            Write-Host ('  [4] ' + $script:S.SpPowerRevertItem)
        }
        else {
            Write-Host ('  [3] ' + $script:S.SpSliderItem)
            Write-Host ('      ' + $script:S.SpPowerWhy[$fit]) -ForegroundColor DarkGray
        }
        Write-Host ''
        Write-Host ('  ' + $script:S.SpActions)
        Write-Host ''
        $ans = (Read-Host ('  ' + $script:S.Choice)).Trim()
        if ($ans -eq '0' -or $ans -eq '') { return }
        switch ($ans) {
            '1' { if (Test-Yes (Read-Host ('  ' + $script:S.SpSoundAsk))) { Invoke-SpSoundsOff } }
            '2' { Invoke-SpSoundRevert }
            '3' {
                if ($fit -eq 'ok' -or $fit -eq 'create') { if (Test-Yes (Read-Host ('  ' + $script:S.SpPowerAsk))) { Invoke-SpPowerHigh } }
                else { Start-Process 'ms-settings:powersleep' }
            }
            '4' { if ($fit -eq 'ok' -or $fit -eq 'create') { Invoke-SpPowerRevert } else { Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow } }
            default { Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow }
        }
        Pause-Return
    }
}
