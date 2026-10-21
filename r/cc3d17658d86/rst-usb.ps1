<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): по ЯВНОМУ выбору скачивает с downloadmirror.intel.com один из трёх пакетов
  Intel RST (SetupRST.exe) из фиксированного списка, сверяет SHA-256 с закреплённой суммой и подпись Authenticode (O=Intel Corporation)
  на файле, удерживаемом открытым, и запускает его только с ключом -extractdrivers в папку на выбранной съёмной флешке. Ничего не
  ставит в эту Windows. Временный файл удаляется.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$script:RstPackages = @(
    @{ Id = 'rst20'; Gens = '12-15'; Version = '20.2.6.1025.3'; Url = 'https://downloadmirror.intel.com/872385/SetupRST.exe';
       Sha = 'C64BE83B75EDC6F516C963A18165BA0853970B078874832545FF99A3404EAC10'; Page = 'https://www.intel.com/content/www/us/en/download/849936/' },
    @{ Id = 'rst18'; Gens = '10-11'; Version = '18.7.6.1010.3'; Url = 'https://downloadmirror.intel.com/773229/SetupRST.exe';
       Sha = 'A2B2E20D6D8100E9EE344746F80849524C64490B90686A13C09268CADB976B37'; Page = 'https://www.intel.com/content/www/us/en/download/19512/' },
    @{ Id = 'rst17'; Gens = '8-9'; Version = '17.11.3.1010.2'; Url = 'https://downloadmirror.intel.com/773230/SetupRST.exe';
       Sha = 'BC077F9C784305330DF66195FF8C96FCE753B1E370189A6E036005B9E589F7AD'; Page = 'https://www.intel.com/content/www/us/en/download/19755/' }
)
$script:RstPin = @{ Type = 'O'; Value = 'Intel Corporation' }

function Get-RstSuggested {
    $name = ''
    try { $name = "$((Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1).Name)" } catch {}
    if ($name -notmatch 'Intel') { return $null }
    $gen = 0
    if ($name -match '(\d{2})th Gen') { $gen = [int]$Matches[1] }
    elseif ($name -match 'Core\(TM\) Ultra') { $gen = 15 }
    elseif ($name -match 'i[3579]-(\d{2})\d{3}') { $gen = [int]$Matches[1] }
    elseif ($name -match 'i[3579]-(1[01])\d{2}G\d') { $gen = [int]$Matches[1] }
    elseif ($name -match 'i[3579]-(\d)\d{3}') { $gen = [int]$Matches[1] }
    if ($gen -ge 12) { return 'rst20' }
    if ($gen -ge 10) { return 'rst18' }
    if ($gen -ge 8) { return 'rst17' }
    return $null
}

function Get-RstDrives {
    try { return @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=2' -ErrorAction Stop | Where-Object { $_.DeviceID -match '^[A-Z]:$' }) }
    catch { return @() }
}

function Get-RstSha([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $fs = [IO.File]::OpenRead($Path)
    try { $h = $sha.ComputeHash($fs) } finally { $fs.Dispose(); $sha.Dispose() }
    return (($h | ForEach-Object { $_.ToString('X2') }) -join '')
}

function Invoke-RstExtract($Pkg, $Drive) {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('as-rst-' + [guid]::NewGuid().ToString('N') + '.exe')
    $dest = Join-Path ($Drive.DeviceID + '\') ('Drivers\IntelRST-' + $Pkg.Version)
    $lock = $null
    Start-Work
    try {
        Write-Live $script:S.RstDownloading
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            (New-Object Net.WebClient).DownloadFile($Pkg.Url, $tmp)
        }
        catch { Clear-Live; Add-Outcome 'fail' ($script:S.RstNoDownload -f $Pkg.Page); return }
        $lock = [IO.File]::Open($tmp, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        if ((Get-RstSha $tmp) -ne $Pkg.Sha) { Clear-Live; Add-Outcome 'fail' ($script:S.RstBadSum -f $Pkg.Page); return }
        if (-not (Test-TrustedExe $tmp @($script:RstPin))) { Clear-Live; Add-Outcome 'fail' $script:S.RstBadSig; return }
        Write-Live $script:S.RstExtracting
        $rc = 1
        try {
            $p = Start-Process -FilePath $tmp -ArgumentList @('-extractdrivers', ('"' + $dest + '"')) -Wait -PassThru -ErrorAction Stop
            $rc = $p.ExitCode
        }
        catch { $rc = -1 }
        Clear-Live
        $inf = @(Get-ChildItem -LiteralPath $dest -Recurse -Filter '*.inf' -ErrorAction SilentlyContinue)
        if ($rc -eq 0 -and $inf.Count -gt 0) {
            Add-Outcome 'ok' ($script:S.RstDone -f $dest)
            Add-Outcome 'note' $script:S.RstHowTo
        }
        elseif ($rc -eq -1) { Add-Outcome 'warn' $script:S.RepairDeclined }
        else { Add-Outcome 'fail' ($script:S.RstExtractFail -f $rc) }
    }
    finally {
        if ($lock) { $lock.Dispose() }
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        Show-Outcome
    }
}

function Invoke-RstUsbScreen {
    while ($true) {
        $hint = Get-RstSuggested
        Write-Host ''
        Write-Host ('  ' + $script:S.RstTitle) -ForegroundColor Cyan
        Write-Host ''
        foreach ($l in $script:S.RstLead) { Write-Host ('  ' + $l) -ForegroundColor DarkGray }
        Write-Host ''
        for ($i = 0; $i -lt $script:RstPackages.Count; $i++) {
            $pk = $script:RstPackages[$i]
            $mark = if ($pk.Id -eq $hint) { '  ' + $script:S.RstThisPc } else { '' }
            Write-Host ('  [{0}] {1}{2}' -f ($i + 1), ($script:S.RstPkg -f $pk.Gens, $pk.Version), $mark)
        }
        Write-Host ''
        Write-Host ('  ' + $script:S.RstActions)
        Write-Host ''
        $ans = (Read-Host ('  ' + $script:S.Choice)).Trim()
        if ($ans -eq '0' -or $ans -eq '') { return }
        $num = 0
        if (-not ([int]::TryParse($ans, [ref]$num) -and $num -ge 1 -and $num -le $script:RstPackages.Count)) {
            Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow; Pause-Return; continue
        }
        $pkg = $script:RstPackages[$num - 1]
        $drives = Get-RstDrives
        Write-Host ''
        if ($drives.Count -eq 0) { Write-Host ('  ' + $script:S.RstNoUsb) -ForegroundColor Yellow; Pause-Return; continue }
        for ($i = 0; $i -lt $drives.Count; $i++) {
            $d = $drives[$i]
            Write-Host ('  [{0}] {1} {2} - {3:N1} GB' -f ($i + 1), $d.DeviceID, $d.VolumeName, ([double]$d.FreeSpace / 1GB))
        }
        Write-Host ''
        $dn = 0
        $pick = (Read-Host ('  ' + $script:S.RstPickUsb)).Trim()
        if (-not ([int]::TryParse($pick, [ref]$dn) -and $dn -ge 1 -and $dn -le $drives.Count)) { continue }
        if (Test-Yes (Read-Host ('  ' + ($script:S.RstAsk -f $pkg.Version, $drives[$dn - 1].DeviceID)))) { Invoke-RstExtract $pkg $drives[$dn - 1] }
        Pause-Return
    }
}
