<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): экран «О компьютере» ТОЛЬКО ЧИТАЕТ и ничего
  не пишет, не повышает права и ничего не запускает: процессор, память, видеокарта, диски, версия и
  сборка Windows, TPM и безопасная загрузка, состояние шифрования системного диска; на Windows 10 -
  есть ли последняя версия 22H2 и где страница продления обновлений (ESU).
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$script:PiEsuUrl = 'https://www.microsoft.com/windows/extended-security-updates'
$script:PiKeyUrl = 'https://account.microsoft.com/devices/recoverykey'

function Get-PiCim($Class, $Namespace = 'root/cimv2') {
    try { return @(Get-CimInstance -Namespace $Namespace -ClassName $Class -ErrorAction Stop) } catch { return @() }
}

function Get-PiValue($Path, $Name) {
    try { return (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop).$Name } catch { return $null }
}

function Get-PiTpm {
    $t = @(Get-PiCim 'Win32_Tpm' 'root/cimv2/Security/MicrosoftTpm')[0]
    if (-not $t -or -not $t.SpecVersion) { return $null }
    return (("$($t.SpecVersion)" -split ',')[0]).Trim()
}

function Get-PiSecureBoot {
    $v = Get-PiValue 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State' 'UEFISecureBootEnabled'
    if ($null -eq $v) { return $null }
    return ([int]$v -eq 1)
}

function Get-PiBitLocker {
    try {
        $drive = $env:SystemDrive + '\'
        $v = (New-Object -ComObject Shell.Application).NameSpace($drive).Self.ExtendedProperty('System.Volume.BitLockerProtection')
        switch ([int]$v) {
            1 { return 'on' }
            3 { return 'on' }
            6 { return 'on' }
            2 { return 'off' }
            5 { return 'paused' }
        }
    }
    catch {}
    return $null
}

function Get-PiGb($Bytes) { return [math]::Round([double]$Bytes / 1GB) }

function Write-PiLine($Label, $Value) {
    if (-not $Value) { $Value = $script:S.PiUnknown }
    Write-Host ('  {0,-22} {1}' -f $Label, $Value)
}

function Invoke-PcInfoScreen {
    Clear-Host
    Write-Host ''
    Write-Host ('  ' + $script:S.PiTitle) -ForegroundColor Cyan
    Write-Host ''
    $nt = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build = [int](Get-PiValue $nt 'CurrentBuildNumber')
    $ubr = Get-PiValue $nt 'UBR'
    $product = "$(Get-PiValue $nt 'ProductName')"
    if ($build -ge 22000) { $product = $product -replace 'Windows 10', 'Windows 11' }
    $ver = "$(Get-PiValue $nt 'DisplayVersion')"
    if (-not $ver) { $ver = "$(Get-PiValue $nt 'ReleaseId')" }
    $win = $null
    if ($product) { $win = ('{0} {1} ({2} {3}.{4})' -f $product, $ver, $script:S.PiBuild, $build, $ubr).Replace('  ', ' ') }
    Write-PiLine $script:S.PiWindows $win

    $cpu = @(Get-PiCim 'Win32_Processor' | ForEach-Object { "$($_.Name)".Trim() } | Select-Object -Unique)
    Write-PiLine $script:S.PiCpu ($cpu -join '; ')
    $cs = @(Get-PiCim 'Win32_ComputerSystem')[0]
    $ram = $null
    if ($cs -and $cs.TotalPhysicalMemory) { $ram = ($script:S.PiGb -f (Get-PiGb $cs.TotalPhysicalMemory)) }
    Write-PiLine $script:S.PiRam $ram
    $gpu = @(Get-PiCim 'Win32_VideoController' | ForEach-Object { "$($_.Name)".Trim() } | Where-Object { $_ } | Select-Object -Unique)
    Write-PiLine $script:S.PiGpu ($gpu -join '; ')
    $disks = @(Get-PiCim 'Win32_DiskDrive' | ForEach-Object { '{0} ({1})' -f "$($_.Model)".Trim(), ($script:S.PiGb -f (Get-PiGb $_.Size)) })
    Write-PiLine $script:S.PiDisks ($disks -join '; ')
    $free = $null
    try { $free = ($script:S.PiGb -f (Get-PiGb (New-Object IO.DriveInfo ($env:SystemDrive)).AvailableFreeSpace)) } catch {}
    Write-PiLine $script:S.PiFree $free

    Write-Host ''
    $tpm = Get-PiTpm
    $tpmText = $null
    if ($tpm) { $tpmText = ($script:S.PiTpmVer -f $tpm) }
    Write-PiLine 'TPM' $tpmText
    $sb = Get-PiSecureBoot
    $sbText = $null
    if ($true -eq $sb) { $sbText = $script:S.PiOn } elseif ($false -eq $sb) { $sbText = $script:S.PiOff }
    Write-PiLine $script:S.PiSecureBoot $sbText
    $bl = Get-PiBitLocker
    $blText = $null
    switch ("$bl") { 'on' { $blText = $script:S.PiOn } 'off' { $blText = $script:S.PiOff } 'paused' { $blText = $script:S.PiPaused } }
    Write-PiLine $script:S.PiBitLocker $blText

    Write-Host ''
    if ($build -gt 0 -and $build -lt 22000) {
        if ($build -ge 19045) { Write-Host ('  ' + $script:S.PiW10Last) } else { Write-Host ('  ' + $script:S.PiW10Old) -ForegroundColor Yellow }
        Write-Host ('  ' + ($script:S.PiEsu -f $script:PiEsuUrl))
        Write-Host ('  ' + $script:S.PiW11Need) -ForegroundColor DarkGray
    }
    if ('on' -eq $bl) { Write-Host ('  ' + ($script:S.PiKey -f $script:PiKeyUrl)) -ForegroundColor DarkGray }
    Write-Host ''
    [void](Read-Host ('  ' + $script:S.PressEnter))
}
