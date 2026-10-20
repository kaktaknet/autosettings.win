<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): только открывает стандартные окна настроек Windows из системной папки (appwiz.cpl, ncpa.cpl и др.).
  Ничего не меняет и прав администратора не просит.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$script:ClassicPanels = @(
    @{ Id = 'control';   File = 'control.exe';   Args = @() },
    @{ Id = 'programs';  File = 'appwiz.cpl';    Args = @() },
    @{ Id = 'network';   File = 'ncpa.cpl';      Args = @() },
    @{ Id = 'sound';     File = 'mmsys.cpl';     Args = @() },
    @{ Id = 'mouse';     File = 'main.cpl';      Args = @() },
    @{ Id = 'power';     File = 'powercfg.cpl';  Args = @() },
    @{ Id = 'printers';  File = 'control.exe';   Args = @('printers') },
    @{ Id = 'region';    File = 'intl.cpl';      Args = @() },
    @{ Id = 'timedate';  File = 'timedate.cpl';  Args = @() },
    @{ Id = 'system';    File = 'sysdm.cpl';     Args = @() },
    @{ Id = 'security';  File = 'wscui.cpl';     Args = @() },
    @{ Id = 'firewall';  File = 'firewall.cpl';  Args = @() },
    @{ Id = 'computer';  File = 'compmgmt.msc';  Args = @() },
    @{ Id = 'restore';   File = 'rstrui.exe';    Args = @() }
)

function Open-ClassicPanel($Panel) {
    $path = Join-Path ([Environment]::SystemDirectory) $Panel.File
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    if (@($Panel.Args).Count -gt 0) { Start-Process -FilePath $path -ArgumentList $Panel.Args }
    else { Start-Process -FilePath $path }
    return $true
}

function Invoke-ClassicPanelsScreen {
    while ($true) {
        Write-Host ''
        Write-Host ('  ' + $script:S.PanelsTitle) -ForegroundColor Cyan
        Write-Host ''
        for ($i = 0; $i -lt $script:ClassicPanels.Count; $i++) {
            Write-Host ('  [{0,2}] {1}' -f ($i + 1), $script:S.Panels[$script:ClassicPanels[$i].Id])
        }
        Write-Host ''
        Write-Host ('  ' + $script:S.PanelsActions)
        Write-Host ''
        $ans = (Read-Host ('  ' + $script:S.Choice)).Trim()
        if ($ans -eq '0' -or $ans -eq '') { return }
        $num = 0
        if ([int]::TryParse($ans, [ref]$num) -and $num -ge 1 -and $num -le $script:ClassicPanels.Count) {
            if (-not (Open-ClassicPanel $script:ClassicPanels[$num - 1])) {
                Write-Host ''; Write-Host ('  ' + $script:S.PanelsMissing) -ForegroundColor Yellow; Pause-Return
            }
        }
        else { Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow; Pause-Return }
    }
}
