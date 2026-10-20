<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): по ЯВНОМУ выбору включает или выключает компоненты Windows через DISM из фиксированного списка:
  .NET Framework 3.5, Песочница, Hyper-V, DirectPlay. Выключение - возврат. Окно администратора.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$script:Components = @(
    @{ Id = 'netfx3';  Feature = 'NetFx3';                          Arch = @('x64', 'arm64', 'x86'); NoHome = $false },
    @{ Id = 'sandbox'; Feature = 'Containers-DisposableClientVM';   Arch = @('x64', 'arm64');        NoHome = $true },
    @{ Id = 'hyperv';  Feature = 'Microsoft-Hyper-V-All';           Arch = @('x64', 'arm64');        NoHome = $true },
    @{ Id = 'directplay'; Feature = @('LegacyComponents', 'DirectPlay'); Arch = @('x64', 'x86');       NoHome = $false },
    @{ Id = 'recall';  Feature = 'Recall';                          Arch = @('x64', 'arm64');        NoHome = $false; MinBuild = 26100 }
)

function Test-ComponentFits($C) {
    if (-not (@($C.Arch) -contains $script:Arch)) { return $false }
    if ($C.NoHome -and "$edition" -like 'Core*') { return $false }
    if ($C.MinBuild -and $build -lt [int]$C.MinBuild) { return $false }
    return $true
}

function Get-ComponentCode($C, [bool]$Enable) {
    $verb = if ($Enable) { '/Enable-Feature' } else { '/Disable-Feature' }
    $all = if ($Enable) { ' /All' } else { '' }
    $names = (@($C.Feature) | ForEach-Object { '/FeatureName:' + $_ }) -join ' '
    return '& (Join-Path ([Environment]::SystemDirectory) ''Dism.exe'') /Online ' + $verb + ' ' + $names + $all + ' /NoRestart /Quiet | Out-Null; exit $LASTEXITCODE'
}

function Invoke-ComponentAction($C, [bool]$Enable) {
    $text = $script:S.Comp[$C.Id]
    Write-Host ''
    $ask = if ($Enable) { $script:S.CompEnableAsk } else { $script:S.CompDisableAsk }
    if (-not (Test-Yes (Read-Host ('  ' + ($ask -f $text.Name))))) { return }
    Start-Work
    Write-Live $script:S.LiveUac
    $rc = Invoke-ElevatedFixed (Get-ComponentCode $C $Enable)
    Clear-Live
    switch ($rc) {
        0 { Add-Outcome 'ok' $(if ($Enable) { $script:S.CompOn -f $text.Name } else { $script:S.CompOff -f $text.Name }) }
        3010 { Add-Outcome 'warn' ($script:S.CompReboot -f $text.Name) }
        -1 { Add-Outcome 'warn' $script:S.RepairDeclined }
        default { Add-Outcome 'fail' ($script:S.CompFail -f $text.Name, $rc) }
    }
    Show-Outcome
}

function Invoke-ComponentsScreen {
    $list = @($script:Components | Where-Object { Test-ComponentFits $_ })
    while ($true) {
        Write-Host ''
        Write-Host ('  ' + $script:S.CompTitle) -ForegroundColor Cyan
        Write-Host ''
        Write-Host ('  ' + $script:S.CompLead) -ForegroundColor DarkGray
        Write-Host ''
        for ($i = 0; $i -lt $list.Count; $i++) {
            $t = $script:S.Comp[$list[$i].Id]
            Write-Host ('  [{0,2}] {1} - {2}' -f ($i + 1), $t.Name, $t.Desc)
        }
        Write-Host ''
        Write-Host ('  ' + $script:S.CompActions)
        Write-Host ''
        $ans = (Read-Host ('  ' + $script:S.Choice)).Trim()
        if ($ans -eq '0' -or $ans -eq '') { return }
        $off = $false
        if ((Get-Key $ans.Substring(0, 1)) -eq 'r') { $off = $true; $ans = $ans.Substring(1).Trim() }
        $num = 0
        if ([int]::TryParse($ans, [ref]$num) -and $num -ge 1 -and $num -le $list.Count) {
            Invoke-ComponentAction $list[$num - 1] (-not $off)
        }
        else { Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow }
        Pause-Return
    }
}
