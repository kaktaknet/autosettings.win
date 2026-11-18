<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): по ЯВНОМУ выбору меняет пять документированных
  параметров SystemParametersInfo текущего пользователя: показ указателя по нажатию Ctrl, ширину
  текстового курсора, время двойного щелчка, подчёркивание букв быстрого доступа и «повышенную
  точность указателя». До первой правки записывает снимок всех пяти прежних значений, возврат ставит
  их обратно. Прав администратора не просит, реестр напрямую не пишет, ничего не запускает.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$script:RdSnapId = 'readability'
$script:RdFlags = 3
$script:RdApi = $null

function Get-RdApi {
    if ($script:RdApi) { return $script:RdApi }
    try {
        if (-not ('AutoSettings.Spi' -as [type])) {
            Add-Type -Namespace AutoSettings -Name Spi -ErrorAction Stop -MemberDefinition @'
[DllImport("user32.dll", EntryPoint = "SystemParametersInfoW", SetLastError = true)]
public static extern bool SetValue(uint action, uint uiParam, IntPtr pvParam, uint flags);
[DllImport("user32.dll", EntryPoint = "SystemParametersInfoW", SetLastError = true)]
public static extern bool GetInt(uint action, uint uiParam, ref int pvParam, uint flags);
[DllImport("user32.dll", EntryPoint = "SystemParametersInfoW", SetLastError = true)]
public static extern bool Ints(uint action, uint uiParam, int[] pvParam, uint flags);
[DllImport("user32.dll")]
public static extern uint GetDoubleClickTime();
'@
        }
        [void][AutoSettings.Spi]::GetDoubleClickTime()
        $script:RdApi = [AutoSettings.Spi]
    }
    catch { $script:RdApi = $null }
    return $script:RdApi
}

$script:RdItems = @(
    @{ Id = 'sonar'; Rec = $true; Target = 1; Min = 0; Max = 1 },
    @{ Id = 'caret'; Rec = $true; Target = 3; Min = 1; Max = 20 },
    @{ Id = 'dblclick'; Rec = $true; Target = 700; Min = 200; Max = 5000 },
    @{ Id = 'cues'; Rec = $true; Target = 1; Min = 0; Max = 1 },
    @{ Id = 'precision'; Rec = $false; Target = 0; Min = 0; Max = 2 }
)

function Get-RdValue($Api, $Id) {
    $v = 0
    try {
    switch ($Id) {
        'sonar' { if ($Api::GetInt(0x101C, 0, [ref]$v, 0)) { return [int]([bool]$v) } }
        'caret' { if ($Api::GetInt(0x2006, 0, [ref]$v, 0)) { return $v } }
        'dblclick' { return [int]$Api::GetDoubleClickTime() }
        'cues' { if ($Api::GetInt(0x100A, 0, [ref]$v, 0)) { return [int]([bool]$v) } }
        'precision' { $m = New-Object int[] 3; if ($Api::Ints(0x0003, 0, $m, 0)) { return $m[2] } }
    }
    }
    catch {}
    return $null
}

function Set-RdValue($Api, $Id, [int]$Value) {
    try {
    switch ($Id) {
        'sonar' { return $Api::SetValue(0x101D, 0, [IntPtr]$Value, $script:RdFlags) }
        'caret' { return $Api::SetValue(0x2007, 0, [IntPtr]$Value, $script:RdFlags) }
        'dblclick' { return $Api::SetValue(0x0020, [uint32]$Value, [IntPtr]::Zero, $script:RdFlags) }
        'cues' { return $Api::SetValue(0x100B, 0, [IntPtr]$Value, $script:RdFlags) }
        'precision' {
            $m = New-Object int[] 3
            if (-not $Api::Ints(0x0003, 0, $m, 0)) { return $false }
            if ($Value -eq 0) { $m = [int[]]@(0, 0, 0) } elseif ($m[0] -eq 0 -and $m[1] -eq 0) { $m = [int[]]@(6, 10, $Value) } else { $m[2] = $Value }
            return $Api::Ints(0x0004, 0, $m, $script:RdFlags)
        }
    }
    }
    catch {}
    return $false
}

function Save-RdSnapshot($Api) {
    $dir = Get-PrivateCopyDir
    if (Get-LatestIn $dir $script:RdSnapId) { return $true }
    $entries = @(foreach ($it in $script:RdItems) {
            $v = Get-RdValue $Api $it.Id
            if ($null -ne $v) { @{ Id = $it.Id; Value = [int]$v } }
        })
    return [bool](Write-SnapshotFile $entries $script:RdSnapId (Get-Date -Format 'yyyyMMdd-HHmmss') $dir)
}

function Invoke-RdApply($Api, $Picked) {
    Start-Work
    try { $saved = Save-RdSnapshot $Api } catch { $saved = $false }
    if (-not $saved) { Add-Outcome 'fail' $script:S.RdNoSnap; Show-Outcome; return }
    $done = @(); $bad = @()
    foreach ($it in @($Picked)) {
        Write-Live $script:S.RdNames[$it.Id]
        if ((Set-RdValue $Api $it.Id $it.Target) -and (Get-RdValue $Api $it.Id) -eq $it.Target) { $done += $script:S.RdNames[$it.Id] }
        else { $bad += $script:S.RdNames[$it.Id] }
    }
    Clear-Live
    if ($done.Count -gt 0) { Add-Outcome 'ok' ($script:S.RdDone -f ($done -join ', ')) }
    if ($bad.Count -gt 0) { Add-Outcome 'fail' ($script:S.RdFail -f ($bad -join ', ')) }
    Show-Outcome
}

function Invoke-RdRevert($Api) {
    Start-Work
    $path = Get-LatestIn (Get-PrivateCopyDir) $script:RdSnapId
    if (-not $path) { Add-Outcome 'warn' $script:S.RdNoBack; Show-Outcome; return }
    $entries = $null
    try { $entries = @((Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json).entries) } catch {}
    if ($null -eq $entries) { Add-Outcome 'fail' $script:S.RdBadSnap; Show-Outcome; return }
    Write-Live ''
    $failed = 0
    foreach ($e in $entries) {
        $it = @($script:RdItems | Where-Object { $_.Id -eq "$($e.Id)" })[0]
        $v = 0
        if (-not $it -or -not [int]::TryParse("$($e.Value)", [ref]$v) -or $v -lt $it.Min -or $v -gt $it.Max) { $failed++; continue }
        if (-not (Set-RdValue $Api $it.Id $v)) { $failed++ }
    }
    Clear-Live
    if ($failed -eq 0) { Remove-SnapshotFiles $path; Add-Outcome 'ok' $script:S.RdBack }
    else { Add-Outcome 'warn' ($script:S.RdPartial -f $failed) }
    Show-Outcome
}

function Invoke-ReadabilityScreen {
    $api = Get-RdApi
    if (-not $api) {
        Write-Host ''
        Write-Host ('  ' + $script:S.RdNoApi) -ForegroundColor Yellow
        Pause-Return
        return
    }
    while ($true) {
        Write-Host ''
        Write-Host ('  ' + $script:S.RdTitle) -ForegroundColor Cyan
        Write-Host ''
        $n = 0
        foreach ($it in $script:RdItems) {
            $n++
            $mark = ' '
            if ((Get-RdValue $api $it.Id) -eq $it.Target) { $mark = '+' }
            Write-Host ('  [{0}] [{1}] {2}' -f $n, $mark, $script:S.RdItems[$it.Id])
        }
        Write-Host ''
        Write-Host ('  ' + $script:S.RdActions)
        Write-Host ''
        $ans = (Read-Host ('  ' + $script:S.Choice)).Trim()
        if ($ans -eq '0' -or $ans -eq '') { return }
        $key = Get-Key $ans
        if ($key -eq 'r') { Invoke-RdRevert $api; Pause-Return; continue }
        if ($key -eq 'a') { Invoke-RdApply $api @($script:RdItems | Where-Object { $_.Rec }); Pause-Return; continue }
        $picked = @(); $bad = $false
        foreach ($tok in @($ans -split '[,\s]+' | Where-Object { $_ -ne '' })) {
            $num = 0
            if ([int]::TryParse($tok, [ref]$num) -and $num -ge 1 -and $num -le $script:RdItems.Count) { $picked += $script:RdItems[$num - 1] }
            else { $bad = $true }
        }
        if ($bad -or $picked.Count -eq 0) { Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow; Pause-Return; continue }
        Invoke-RdApply $api $picked
        Pause-Return
    }
}
