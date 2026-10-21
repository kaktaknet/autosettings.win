<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): по ЯВНОМУ выбору выключает системные звуки текущего пользователя (схема «Без звуков»:
  значения .Current в HKCU\AppEvents) и включает встроенную схему питания «Высокая производительность» только на компьютере без
  батареи и без Modern Standby. До правки записывает снимок (звуки - каждое значение, питание - GUID прежней схемы), возврат
  восстанавливает его. Прав администратора не просит.
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

function Get-SpPowerFit {
    $caps = Get-SpPowerCaps
    if ($null -eq $caps) { return 'unknown' }
    if ($caps.ModernStandby -or $caps.Battery) { return 'mobile' }
    if (Test-SpPowerManaged) { return 'managed' }
    if (-not (@(Get-SpSchemes) -contains $script:SpHighPerf)) { return 'missing' }
    return 'ok'
}

function Set-SpActive($Guid) {
    $exe = Get-SpPowercfg
    if (-not $exe) { return $false }
    $rc = Invoke-Quiet $exe @('/setactive', $Guid)
    return ($rc -eq 0 -and (Get-SpActiveScheme) -eq $Guid)
}

function Invoke-SpPowerHigh {
    $fit = Get-SpPowerFit
    if ($fit -ne 'ok') { Start-Work; Add-Outcome 'warn' $script:S.SpPowerWhy[$fit]; Show-Outcome; return }
    $now = Get-SpActiveScheme
    if ($now -eq $script:SpHighPerf) { Start-Work; Add-Outcome 'ok' $script:S.SpPowerAlready; Show-Outcome; return }
    $dir = Get-PrivateCopyDir
    if ($now -and -not (Get-LatestIn $dir $script:SpPowerSnapId)) {
        [void](Write-SnapshotFile @(@{ Active = $now }) $script:SpPowerSnapId (Get-Date -Format 'yyyyMMdd-HHmmss') $dir)
    }
    Start-Work
    Write-Live $script:S.SpPowerName
    $ok = Set-SpActive $script:SpHighPerf
    Clear-Live
    if ($ok) { Add-Outcome 'ok' $script:S.SpPowerDone } else { Add-Outcome 'fail' $script:S.SpPowerFail }
    Show-Outcome
}

function Invoke-SpPowerRevert {
    $path = Get-LatestIn (Get-PrivateCopyDir) $script:SpPowerSnapId
    if (-not $path) { Start-Work; Add-Outcome 'warn' $script:S.SpNoSnap; Show-Outcome; return }
    $guid = $null
    try { $guid = "$(@((Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json).entries)[0].Active)".ToLowerInvariant() } catch {}
    $failed = 0
    $refused = 0
    if (-not ($guid -match ('^' + $script:SpGuidRx + '$')) -or -not (@(Get-SpSchemes) -contains $guid)) { $refused++ }
    else {
        Start-Work
        Write-Live $script:S.SpPowerName
        if (-not (Set-SpActive $guid)) { $failed++ }
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
        if ($fit -eq 'ok') {
            Write-Host ('  [3] ' + $script:S.SpPowerItem)
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
                if ($fit -eq 'ok') { if (Test-Yes (Read-Host ('  ' + $script:S.SpPowerAsk))) { Invoke-SpPowerHigh } }
                else { Start-Process 'ms-settings:powersleep' }
            }
            '4' { if ($fit -eq 'ok') { Invoke-SpPowerRevert } else { Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow } }
            default { Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow }
        }
        Pause-Return
    }
}
