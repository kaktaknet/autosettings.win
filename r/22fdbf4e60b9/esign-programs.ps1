<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): по ЯВНОМУ выбору ставит программы для электронной подписи, которых нет в winget, только
  после проверки подписи Authenticode и точного имени издателя: качает установщик с закреплённого https-адреса производителя или берёт файл,
  который человек скачал сам, копирует его в личную папку, сверяет подпись копии и запускает копию. Файл без нужной подписи не запускается.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$script:EsignPinCryptoPro = @{ Type = 'O'; Value = 'CRYPTO-PRO LLC' }
$script:EsignPinRostelecom = @{ Type = 'O'; Value = 'Rostelecom PAO' }
$script:EsignItems = @(
    @{ Id = 'gosuslugi'; Kind = 'download'; Pins = @($script:EsignPinRostelecom)
       Url = @{ x64 = 'https://ds-plugin.gosuslugi.ru/plugin/upload/assets/distrib/IFCPlugin-x64.msi'; x86 = 'https://ds-plugin.gosuslugi.ru/plugin/upload/assets/distrib/IFCPlugin.msi' } },
    @{ Id = 'cades'; Kind = 'page'; Pins = @($script:EsignPinCryptoPro); Page = 'https://cryptopro.ru/products/cades/plugin' },
    @{ Id = 'csp'; Kind = 'page'; Pins = @($script:EsignPinCryptoPro); Page = 'https://cryptopro.ru/products/csp/downloads' },
    @{ Id = 'rutoken'; Kind = 'winget'; WingetId = 'AktivCo.RutokenDrivers'; Arch = @('x64') },
    @{ Id = 'vipnet'; Kind = 'info'; Page = 'https://infotecs.ru/downloads/' },
    @{ Id = 'rutoken-plugin'; Kind = 'info'; Page = 'https://www.rutoken.ru/support/download/rutoken-plugin/' },
    @{ Id = 'rutoken-connect'; Kind = 'info'; Page = 'https://www.rutoken.ru/products/all/rutoken-connect/' },
    @{ Id = 'jacarta'; Kind = 'info'; Page = 'https://www.aladdin-rd.ru/support/downloads/jacarta_client/' },
    @{ Id = 'esmart'; Kind = 'info'; Page = 'https://token.esmart.ru/downloads' }
)
$script:EsignExt = @('.msi', '.exe')

function Test-EsignFits($Item) {
    if ($Item.Kind -eq 'download') { return [bool]$Item.Url[$script:Arch] }
    if ($Item.Arch) { return (@($Item.Arch) -contains $script:Arch) }
    return $true
}

function Copy-EsignToPrivate([string]$Source, [string]$Ext) {
    $dst = Join-Path (Get-PrivateCopyDir) ('esign-' + [Guid]::NewGuid().ToString('N') + $Ext)
    $in = [IO.File]::Open($Source, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $out = [IO.File]::Open($dst, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $in.CopyTo($out) } finally { $out.Dispose() }
    }
    finally { $in.Dispose() }
    return $dst
}

function Get-EsignSigner([string]$Path) {
    try {
        $sig = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
        if ($sig.SignerCertificate) { return "$($sig.SignerCertificate.Subject)" }
    }
    catch {}
    return ''
}

function Invoke-EsignVerifiedRun($Item, [string]$Copy, [string]$Name) {
    $lock = $null
    try {
        try { $lock = [IO.File]::Open($Copy, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read) }
        catch { Add-Outcome 'fail' ($script:S.EsignFail -f $Name, -1); return }
        if (-not (Test-TrustedExe $Copy $Item.Pins)) {
            $who = Get-EsignSigner $Copy
            if (-not $who) { $who = $script:S.EsignNoSig }
            Add-Outcome 'fail' ($script:S.EsignBadSig -f $Name, $who)
            return
        }
        Add-Outcome 'ok' ($script:S.EsignSigOk -f $Name, @($Item.Pins | ForEach-Object { $_.Value }) -join ', ')
        Clear-Live
        Write-Host ''
        Write-Host ('  ' + $script:S.EsignRunning) -ForegroundColor DarkGray
        $rc = 1
        try {
            if ([IO.Path]::GetExtension($Copy) -eq '.msi') {
                $msi = Join-Path ([Environment]::SystemDirectory) 'msiexec.exe'
                $p = Start-Process -FilePath $msi -ArgumentList @('/i', ('"' + $Copy + '"')) -PassThru -ErrorAction Stop
            }
            else { $p = Start-Process -FilePath $Copy -PassThru -ErrorAction Stop }
            Write-Live $Name
            [void](Wait-Watched $p)
            Clear-Live
            $rc = $p.ExitCode
        }
        catch { $rc = -1 }
        switch ($rc) {
            0 { Add-Outcome 'ok' ($script:S.EsignDone -f $Name) }
            3010 { Add-Outcome 'warn' ($script:S.EsignReboot -f $Name) }
            1602 { Add-Outcome 'warn' ($script:S.EsignCancelled -f $Name) }
            default { Add-Outcome 'fail' ($script:S.EsignFail -f $Name, $rc) }
        }
    }
    finally {
        if ($lock) { $lock.Dispose() }
        Remove-Item -LiteralPath $Copy -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-EsignDownload($Item, [string]$Name) {
    $url = $Item.Url[$script:Arch]
    if (-not "$url".StartsWith('https://')) { Add-Outcome 'fail' ($script:S.EsignFail -f $Name, 'url'); return }
    $ext = [IO.Path]::GetExtension(([Uri]$url).AbsolutePath).ToLowerInvariant()
    $copy = Join-Path (Get-PrivateCopyDir) ('esign-' + [Guid]::NewGuid().ToString('N') + $ext)
    Write-Live $Name
    try { (New-Object Net.WebClient).DownloadFile($url, $copy) }
    catch { Remove-Item -LiteralPath $copy -Force -ErrorAction SilentlyContinue; Add-Outcome 'fail' ($script:S.EsignNoDownload -f $Name); return }
    Invoke-EsignVerifiedRun $Item $copy $Name
}

function Invoke-EsignFromPage($Item, [string]$Name) {
    try { Start-Process $Item.Page } catch {}
    Write-Host ''
    foreach ($l in $script:S.EsignPageSteps) { Write-Host ('  ' + ($l -f $Name)) }
    Write-Host ''
    $raw = (Read-Host ('  ' + $script:S.EsignPathAsk)).Trim().Trim('"').Trim("'").Trim()
    if ($raw -eq '' -or $raw -eq '0') { return $false }
    $ext = [IO.Path]::GetExtension($raw).ToLowerInvariant()
    if (-not ($script:EsignExt -contains $ext) -or -not (Test-Path -LiteralPath $raw -PathType Leaf)) {
        Start-Work; Add-Outcome 'fail' $script:S.EsignBadPath; Show-Outcome; return $true
    }
    Start-Work
    Write-Live $Name
    $copy = $null
    try { $copy = Copy-EsignToPrivate $raw $ext } catch { Add-Outcome 'fail' $script:S.EsignBadPath; Clear-Live; Show-Outcome; return $true }
    Invoke-EsignVerifiedRun $Item $copy $Name
    Clear-Live
    Show-Outcome
    return $true
}

function Invoke-EsignItem($Item) {
    $name = $script:S.Esign[$Item.Id].Name
    switch ($Item.Kind) {
        'info' {
            try { Start-Process $Item.Page } catch {}
            Write-Host ''
            foreach ($l in $script:S.EsignVipnet) { Write-Host ('  ' + $l) -ForegroundColor DarkGray }
        }
        'page' { [void](Invoke-EsignFromPage $Item $name) }
        'download' {
            if (-not (Test-Yes (Read-Host ('  ' + ($script:S.EsignAsk -f $name))))) { return }
            Start-Work
            Invoke-EsignDownload $Item $name
            Clear-Live
            Show-Outcome
        }
        'winget' {
            if (-not (Test-Yes (Read-Host ('  ' + ($script:S.EsignAsk -f $name))))) { return }
            $winget = Get-WingetExe
            Start-Work
            if (-not $winget) { Add-Outcome 'fail' $script:S.BuiltinNoWinget; Show-Outcome; return }
            Write-Live $name
            $rc = Invoke-Quiet $winget @('install', '-e', '--id', $Item.WingetId, '--source', 'winget', '--accept-package-agreements', '--accept-source-agreements', '--silent')
            Clear-Live
            if ($rc -eq 0 -or $script:WingetAlready -contains $rc) { Add-Outcome 'ok' ($script:S.EsignDone -f $name) }
            elseif ($script:WingetReboot -contains $rc) { Add-Outcome 'warn' ($script:S.EsignReboot -f $name) }
            else { Add-Outcome 'fail' ($script:S.EsignFail -f $name, $rc) }
            Show-Outcome
        }
    }
}

function Invoke-EsignProgramsScreen {
    $list = @($script:EsignItems | Where-Object { Test-EsignFits $_ })
    while ($true) {
        Write-Host ''
        Write-Host ('  ' + $script:S.EsignTitle) -ForegroundColor Cyan
        Write-Host ''
        foreach ($l in $script:S.EsignLead) { Write-Host ('  ' + $l) -ForegroundColor DarkGray }
        Write-Host ''
        for ($i = 0; $i -lt $list.Count; $i++) {
            $t = $script:S.Esign[$list[$i].Id]
            Write-Host ('  [{0,2}] {1} - {2}' -f ($i + 1), $t.Name, $t.Desc)
        }
        Write-Host ''
        Write-Host ('  ' + $script:S.EsignActions)
        Write-Host ''
        $ans = (Read-Host ('  ' + $script:S.Choice)).Trim()
        if ($ans -eq '0' -or $ans -eq '') { return }
        $num = 0
        if ([int]::TryParse($ans, [ref]$num) -and $num -ge 1 -and $num -le $list.Count) { Invoke-EsignItem $list[$num - 1] }
        else { Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow }
        Pause-Return
    }
}
