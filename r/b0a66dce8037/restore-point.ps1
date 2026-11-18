<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): по ЯВНОМУ выбору создаёт точку восстановления системы Windows (Checkpoint-Computer в Windows PowerShell 5.1
  из системной папки, окно администратора). Код повышённой части - фиксированная строка из этого файла.
  Защиту системы на диске Windows включает только после отдельного «да». Открывает окно rstrui.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

function Get-RestorePointScript([bool]$Enable) {
    $enableLine = ''
    if ($Enable) { $enableLine = 'Enable-ComputerRestore -Drive $d -ErrorAction Stop;' }
    return '$ErrorActionPreference=''Stop'';$d=$env:SystemDrive+''\'';' +
        'try{' + $enableLine +
        '$before=@(Get-ComputerRestorePoint -ErrorAction SilentlyContinue).Count;' +
        'Checkpoint-Computer -Description ''AutoSettings'' -RestorePointType MODIFY_SETTINGS -WarningAction SilentlyContinue;' +
        '$after=@(Get-ComputerRestorePoint -ErrorAction SilentlyContinue).Count;' +
        'if($after -gt $before){exit 0}else{exit 3}' +
        '}catch{if("$($_.Exception.Message)" -match ''disabled|0x80042306|отключ''){exit 4};exit 1}'
}

function Invoke-RestorePointCreate([bool]$Enable) {
    return (Invoke-ElevatedFixed (Get-RestorePointScript $Enable))
}

function Invoke-RestorePointScreen {
    while ($true) {
        Write-Host ''
        Write-Host ('  ' + $script:S.RpTitle) -ForegroundColor Cyan
        Write-Host ''
        foreach ($l in $script:S.RpLead) { Write-Host ('  ' + $l) -ForegroundColor DarkGray }
        Write-Host ''
        Write-Host ('  ' + $script:S.RpActions)
        Write-Host ''
        $ans = (Read-Host ('  ' + $script:S.Choice)).Trim()

        if ($ans -eq '0' -or $ans -eq '') { return }
        if ($ans -eq '2') {
            $rstrui = Join-Path ([Environment]::SystemDirectory) 'rstrui.exe'
            if (Test-Path -LiteralPath $rstrui) { Start-Process -FilePath $rstrui }
            else { Write-Host ''; Write-Host ('  ' + $script:S.RpNoRstrui) -ForegroundColor Yellow; Pause-Return }
            continue
        }
        if ($ans -ne '1') { Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow; Pause-Return; continue }

        Start-Work
        Write-Live $script:S.LiveUac
        $rc = Invoke-RestorePointCreate $false
        if ($rc -eq 4) {
            Clear-Live
            Write-Host ''
            if (Test-Yes (Read-Host ('  ' + $script:S.RpEnableAsk))) {
                Write-Live $script:S.LiveUac
                $rc = Invoke-RestorePointCreate $true
            }
            else { $rc = 5 }
        }
        Clear-Live
        switch ($rc) {
            0 { Add-Outcome 'ok' $script:S.RpDone }
            3 { Add-Outcome 'warn' $script:S.RpToday }
            4 { Add-Outcome 'fail' $script:S.RpOff }
            5 { Add-Outcome 'warn' $script:S.RpOff }
            -1 { Add-Outcome 'warn' $script:S.RpDeclined }
            default { Add-Outcome 'fail' $script:S.RpFail }
        }
        Show-Outcome
        Pause-Return
    }
}
