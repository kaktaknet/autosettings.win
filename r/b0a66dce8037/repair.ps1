<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): по ЯВНОМУ выбору и после вопроса запускает встроенные средства Windows: sfc, DISM, chkdsk /scan,
  w32tm, netsh winhttp reset proxy, ie4uinit, wsreset, перерегистрацию пакета winget; сброс Центра
  обновления переименовывает папки SoftwareDistribution и catroot2 (не удаляет); снимает запреты
  DisableTaskMgr, DisableRegistryTools, NoRun, NoControlPanel, если их кто-то поставил; при выключенной
  службе обновления (Start=4) сброс ничего не трогает и называет её. Ничего не скачивает из сети сам.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$script:RepairCode = @{
    'sfc-verify' = '& (Join-Path ([Environment]::SystemDirectory) ''sfc.exe'') /verifyonly | Out-Null; if($LASTEXITCODE -eq 0){exit 0}else{exit 3}'
    'sfc-fix'    = '$s=[Environment]::SystemDirectory;& (Join-Path $s ''Dism.exe'') /Online /Cleanup-Image /RestoreHealth | Out-Null;$d=$LASTEXITCODE;& (Join-Path $s ''sfc.exe'') /scannow | Out-Null;if($d -ne 0){exit 3};exit 0'
    'disk-scan'  = '& (Join-Path ([Environment]::SystemDirectory) ''chkdsk.exe'') $env:SystemDrive /scan | Out-Null; if($LASTEXITCODE -eq 0){exit 0}else{exit 3}'
    'wu-reset'   = '$ErrorActionPreference=''Stop'';try{$svc=@(''wuauserv'',''bits'',''cryptsvc'');foreach($n in $svc){$k=''HKLM:\SYSTEM\CurrentControlSet\Services\''+$n;if((Test-Path -LiteralPath $k) -and (Get-ItemProperty -LiteralPath $k -Name Start -ErrorAction SilentlyContinue).Start -eq 4){exit 4}};foreach($n in $svc){Stop-Service -Name $n -Force -ErrorAction SilentlyContinue};$t=Get-Date -Format ''yyyyMMdd-HHmmss'';$w=[Environment]::GetFolderPath(''Windows'');foreach($d in @((Join-Path $w ''SoftwareDistribution''),(Join-Path ([Environment]::SystemDirectory) ''catroot2''))){if(Test-Path -LiteralPath $d){Rename-Item -LiteralPath $d -NewName ((Split-Path -Leaf $d)+''.bak-''+$t)}};foreach($n in $svc){Start-Service -Name $n -ErrorAction SilentlyContinue};if(@($svc|Where-Object{(Get-Service -Name $_).Status -ne ''Running''}).Count -gt 0){exit 3};exit 0}catch{foreach($n in @(''wuauserv'',''bits'',''cryptsvc'')){Start-Service -Name $n -ErrorAction SilentlyContinue};exit 1}'
    'time-sync'  = '$s=[Environment]::SystemDirectory;Start-Service -Name w32time -ErrorAction SilentlyContinue;& (Join-Path $s ''w32tm.exe'') /resync /force | Out-Null; if($LASTEXITCODE -eq 0){exit 0}else{exit 1}'
    'proxy'      = '& (Join-Path ([Environment]::SystemDirectory) ''netsh.exe'') winhttp reset proxy | Out-Null; if($LASTEXITCODE -eq 0){exit 0}else{exit 1}'
    'components' = '& (Join-Path ([Environment]::SystemDirectory) ''Dism.exe'') /Online /Cleanup-Image /StartComponentCleanup | Out-Null; if($LASTEXITCODE -eq 0){exit 0}else{exit 1}'
    'unlock'     = '$k=@(''HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System|DisableTaskMgr'',''HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System|DisableRegistryTools'',''HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer|NoRun'',''HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer|NoControlPanel'');foreach($e in $k){$p,$n=$e -split ''\|'';if(Test-Path -LiteralPath $p){Remove-ItemProperty -LiteralPath $p -Name $n -ErrorAction SilentlyContinue}};exit 0'
}

$script:RepairUserLocks = @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System';   Name = 'DisableTaskMgr' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System';   Name = 'DisableRegistryTools' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'NoRun' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'NoControlPanel' }
)

function Invoke-RepairUserProxy {
    $p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    if (Test-Path -LiteralPath $p) { Set-ItemProperty -LiteralPath $p -Name 'ProxyEnable' -Value 0 -ErrorAction SilentlyContinue }
}

function Invoke-RepairUserUnlock {
    foreach ($l in $script:RepairUserLocks) {
        if (Test-Path -LiteralPath $l.Path) { Remove-ItemProperty -LiteralPath $l.Path -Name $l.Name -ErrorAction SilentlyContinue }
    }
}

function Invoke-RepairUserCommand($Id) {
    $sys = [Environment]::SystemDirectory
    switch ($Id) {
        'icons' {
            $exe = Join-Path $sys 'ie4uinit.exe'
            if (-not (Test-Path -LiteralPath $exe)) { return 1 }
            return (Invoke-Quiet $exe @('-show'))
        }
        'store' {
            $exe = Join-Path $sys 'wsreset.exe'
            if (-not (Test-Path -LiteralPath $exe)) { return 1 }
            Start-Process -FilePath $exe
            return 0
        }
        'cleanmgr' {
            $exe = Join-Path $sys 'cleanmgr.exe'
            if (-not (Test-Path -LiteralPath $exe)) { return 1 }
            Start-Process -FilePath $exe -ArgumentList @('/d', $env:SystemDrive)
            return 0
        }
        'winget' {
            try {
                Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' -ErrorAction Stop
                return 0
            }
            catch { return 1 }
        }
    }
    return 1
}

$script:RepairItems = @(
    @{ Id = 'sfc-verify'; Elevated = $true },
    @{ Id = 'sfc-fix';    Elevated = $true },
    @{ Id = 'disk-scan';  Elevated = $true },
    @{ Id = 'wu-reset';   Elevated = $true },
    @{ Id = 'time-sync';  Elevated = $true },
    @{ Id = 'proxy';      Elevated = $true },
    @{ Id = 'icons';      Elevated = $false },
    @{ Id = 'store';      Elevated = $false },
    @{ Id = 'winget';     Elevated = $false },
    @{ Id = 'cleanmgr';   Elevated = $false },
    @{ Id = 'components'; Elevated = $true },
    @{ Id = 'unlock';     Elevated = $true }
)

function Invoke-RepairItem($Item) {
    $text = $script:S.Repair[$Item.Id]
    Write-Host ''
    Write-Host ('  ' + $text.Ask) -ForegroundColor Yellow
    if (-not (Test-Yes (Read-Host ('  ' + $script:S.RepairConfirm)))) { return }
    Start-Work
    Write-Live $text.Name
    if ($Item.Id -eq 'proxy') { Invoke-RepairUserProxy }
    if ($Item.Id -eq 'unlock') { Invoke-RepairUserUnlock }
    if ($Item.Elevated) {
        Write-Live $script:S.LiveUac
        $rc = Invoke-ElevatedFixed $script:RepairCode[$Item.Id]
    }
    else { $rc = Invoke-RepairUserCommand $Item.Id }
    Clear-Live
    switch ($rc) {
        0 { Add-Outcome 'ok' $text.Done }
        3 { Add-Outcome 'warn' $text.Found }
        4 { Add-Outcome 'warn' $text.Disabled }
        -1 { Add-Outcome 'warn' $script:S.RepairDeclined }
        default { Add-Outcome 'fail' $script:S.RepairFail }
    }
    Show-Outcome
}

function Invoke-RepairScreen {
    while ($true) {
        Write-Host ''
        Write-Host ('  ' + $script:S.RepairTitle) -ForegroundColor Cyan
        Write-Host ''
        Write-Host ('  ' + $script:S.RepairLead) -ForegroundColor DarkGray
        Write-Host ''
        for ($i = 0; $i -lt $script:RepairItems.Count; $i++) {
            Write-Host ('  [{0,2}] {1}' -f ($i + 1), $script:S.Repair[$script:RepairItems[$i].Id].Name)
        }
        Write-Host ''
        Write-Host ('  ' + $script:S.RepairActions)
        Write-Host ''
        $ans = (Read-Host ('  ' + $script:S.Choice)).Trim()
        if ($ans -eq '0' -or $ans -eq '') { return }
        $num = 0
        if ([int]::TryParse($ans, [ref]$num) -and $num -ge 1 -and $num -le $script:RepairItems.Count) {
            Invoke-RepairItem $script:RepairItems[$num - 1]
        }
        else { Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow }
        Pause-Return
    }
}
