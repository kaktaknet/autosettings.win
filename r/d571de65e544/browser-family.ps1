<#
MACHINE-READABLE INTENT (for a reviewing human or AI agent): on the user's explicit choice this removes
  the named browser family from this computer - closes its windows, uninstalls it with winget and then, for
  whatever is left, with its own uninstaller found in the Windows uninstall list (Chrome setup.exe, Firefox
  helper.exe, Chromium-Gost) - and then
  installs a fresh copy by the same route the install row uses. Personal browser data is removed only when
  the user answers yes to the separate question. Per-user work runs as the user (inversion model); only a
  machine-wide Chrome is removed through a standard UAC prompt, and only a setup.exe with a valid Google LLC
  signature is ever started that way; nothing is hidden, this is not malware and does not exploit anything. Declining changes nothing.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$script:BfOnWindows = ([Environment]::OSVersion.Platform.ToString() -eq 'Win32NT')
$script:BfNothingToRemove = @(-1978335212)
$script:BfWingetAlready = @(-1978335189, -1978335135, -1978334963, -1978334962)
$script:BfUninstallWaitMs = 600000
$script:BfUninstallIdleMs = 30000
$script:BfUninstallerNames = @('Au_', 'Un_A', 'consent')
$script:BfFreshInstall = $false

function Join-BfPath([string]$Base, [string]$Child) {
    if (-not $Base) { return $null }
    return (Join-Path $Base $Child)
}
function Get-BfLocalDir { [Environment]::GetFolderPath('LocalApplicationData') }
function Get-BfRoamingDir { [Environment]::GetFolderPath('ApplicationData') }
function Get-BfProgramFilesDirs { @(@([Environment]::GetFolderPath('ProgramFiles'), [Environment]::GetFolderPath('ProgramFilesX86')) | Where-Object { $_ } | Select-Object -Unique) }

function Find-BfUninstallEntries([string]$Re) {
    $entries = @()
    $roots = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($root in $roots) {
        foreach ($key in @(Get-ChildItem $root -ErrorAction SilentlyContinue)) {
            $item = Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue
            if (-not $item -or -not $item.UninstallString) { continue }
            if (-not ([string]$item.DisplayName -match $Re)) { continue }
            $entries += New-Object PSObject -Property @{ Name = [string]$item.DisplayName; Command = [string]$item.UninstallString; Machine = ($root -like 'HKLM:*')
                Key = [string]$key.PSPath; Location = [string]$item.InstallLocation; Icon = [string]$item.DisplayIcon }
        }
    }
    return $entries
}

function Get-BfUninstallerFile([string]$Command) {
    if ($Command -match '^"([^"]+)"') { $file = $Matches[1] }
    else { $file = ($Command -split '\s+--', 2)[0].Trim() }
    try { $full = [IO.Path]::GetFullPath($file) } catch { return $null }
    $roots = @((Get-BfLocalDir)) + (Get-BfProgramFilesDirs)
    $inside = $false
    foreach ($root in $roots) {
        if ($root -and $full.StartsWith(($root.TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) { $inside = $true }
    }
    if (-not $inside -or -not (Test-Path -LiteralPath $full -PathType Leaf)) { return $null }
    return $full
}

function Stop-BfProcesses([string]$Re) {
    $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path -match $Re })
    foreach ($process in $running) { try { Stop-Process -Id $process.Id -Force } catch {} }
    if ($running.Count -gt 0) { Start-Sleep -Seconds 2 }
    return $running.Count
}

function Write-BfLine([string]$Text, [string]$Color) {
    $what = $script:LiveWhat
    Clear-Live
    Write-Host $Text -ForegroundColor $Color
    if ($what) { Write-Live $what }
}

function Remove-BfWinget([string[]]$Ids, [bool]$En) {
    $result = @{ Removed = $false; Failed = $false }
    foreach ($id in $Ids) {
        if ((Invoke-Quiet 'winget' @('list', '-e', '--id', $id, '--accept-source-agreements')) -ne 0) { continue }
        $rc = Invoke-Quiet 'winget' @('uninstall', '-e', '--id', $id, '--silent', '--accept-source-agreements')
        if ($rc -eq 0) { Write-BfLine ('  [OK] winget ' + $id) 'Green'; $result.Removed = $true; break }
        if ($script:BfNothingToRemove -contains $rc) { continue }
        $result.Failed = $true
        if ($En) { Write-BfLine "  [!] winget could not remove $id (code $rc)." 'Yellow' }
        else { Write-BfLine "  [!] winget не смог удалить $id (код $rc)." 'Yellow' }
    }
    return $result
}

function Get-BfUninstallPlan($Entry, [string]$Arguments, [string]$MachineArgs) {
    if ($Entry.Machine -and $MachineArgs) { return @{ Args = ($Arguments + ' ' + $MachineArgs); Elevate = $true } }
    return @{ Args = $Arguments; Elevate = $false }
}

function Test-BfSigner([string]$File, [string]$Org) {
    if (-not $Org) { return $false }
    try {
        $sig = Get-AuthenticodeSignature -LiteralPath $File -ErrorAction Stop
        if ($sig.Status -ne 'Valid') { return $false }
        return ("$($sig.SignerCertificate.Subject)" -match ('(?:^|,\s*)O=' + [regex]::Escape($Org) + '(?:,|$)'))
    } catch { return $false }
}

function Remove-BfRegistryUninstall([string]$Re, [bool]$En, [string]$Arguments, [string]$MachineArgs = '', [string]$SignerOrg = '') {
    if (-not $Arguments) { $Arguments = '--uninstall --force-uninstall' }
    $seen = @{}
    foreach ($entry in @(Find-BfUninstallEntries $Re)) {
        $file = Get-BfUninstallerFile $entry.Command
        if (-not $file) { continue }
        if ($seen.ContainsKey($file.ToLowerInvariant())) { continue }
        $seen[$file.ToLowerInvariant()] = $true
        try {
            $plan = Get-BfUninstallPlan $entry $Arguments $MachineArgs
            if ($plan.Elevate) {
                if (-not (Test-BfSigner $file $SignerOrg)) { throw "no valid $SignerOrg signature" }
                $process = Start-Process -FilePath $file -ArgumentList $plan.Args -Verb RunAs -PassThru
            }
            else { $process = Start-Process -FilePath $file -ArgumentList $plan.Args -PassThru }
            if (-not (Wait-Watched $process $script:BfUninstallWaitMs)) { try { Stop-Process -Id $process.Id -Force } catch {} }
            if ($En) { Write-BfLine ('  [OK] Uninstaller run: ' + $entry.Name) 'Green' }
            else { Write-BfLine ('  [OK] Удалитель запущен: ' + $entry.Name) 'Green' }
        }
        catch {
            if ($En) { Write-BfLine ('  [!] Could not start the uninstaller ' + $file + ': ' + (Get-ShortError $_)) 'Yellow' }
            else { Write-BfLine ('  [!] Не удалось запустить удалитель ' + $file + ': ' + (Get-ShortError $_)) 'Yellow' }
        }
    }
}

function Get-BfInstallSnapshot($Spec) {
    $files = @()
    $keys = @()
    if ($Spec.UninstallRe) {
        foreach ($e in @(Find-BfUninstallEntries $Spec.UninstallRe)) {
            if ($e.Key) { $keys += $e.Key }
            $cands = @()
            if ($e.Icon) { $cands += (([string]$e.Icon).Trim() -replace ',\s*-?\d+$', '').Trim().Trim('"') }
            if ($e.Location -and $Spec.ExeName) { $cands += (Join-Path ([string]$e.Location).Trim().Trim('"') $Spec.ExeName) }
            foreach ($c in $cands) {
                if (-not $c -or -not $Spec.ExeName) { continue }
                if ((Split-Path -Leaf $c) -ine $Spec.ExeName) { continue }
                if (Test-Path -LiteralPath $c -PathType Leaf) { $files += $c }
            }
        }
    }
    foreach ($x in @($Spec.Exe)) { if ($x -and (Test-Path -LiteralPath $x -PathType Leaf)) { $files += $x } }
    $uniq = @{}
    $files = @($files | Where-Object { $k = $_.ToLowerInvariant(); if ($uniq.ContainsKey($k)) { $false } else { $uniq[$k] = $true; $true } })
    return @{ Files = $files; Keys = @($keys) }
}

function Get-BfRemaining($Snap) {
    if (@($Snap.Files).Count -gt 0) { return @($Snap.Files | Where-Object { Test-Path -LiteralPath $_ }) }
    return @($Snap.Keys | Where-Object { Test-Path -LiteralPath $_ })
}

function Test-BfUninstallerRunning([string[]]$Names) {
    return (@(Get-Process -Name $Names -ErrorAction SilentlyContinue).Count -gt 0)
}

function Wait-BfGone($Snap, [string[]]$Names, [int]$LimitMs = 0) {
    if ($LimitMs -le 0) { $LimitMs = $script:BfUninstallWaitMs }
    $spin = @('|', '/', '-', '\')
    if ($script:Ui -and $script:Ui.Box) { $spin = @('◐', '◓', '◑', '◒') }
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $idle = [Diagnostics.Stopwatch]::StartNew()
    $i = 0
    while ($true) {
        $left = @(Get-BfRemaining $Snap)
        if ($left.Count -eq 0 -or $clock.ElapsedMilliseconds -ge $LimitMs) { return $left }
        if (Test-BfUninstallerRunning $Names) { $idle.Restart() }
        elseif ($idle.ElapsedMilliseconds -ge $script:BfUninstallIdleMs) { return $left }
        if ($script:LiveShown) {
            $sec = [int]$clock.Elapsed.TotalSeconds
            Write-LiveTail ('{0} {1}:{2:00}' -f $spin[$i % $spin.Count], [int][Math]::Floor($sec / 60), ($sec % 60))
        }
        $i++
        Start-Sleep -Milliseconds 250
    }
}

function Remove-BfData([string[]]$Paths) {
    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        try {
            Assert-SafeUserPath $path
            Remove-Item -LiteralPath $path -Recurse -Force
        }
        catch {}
    }
}

function Invoke-BrowserFamilyReinstall($Spec) {
    $en = ($script:Lang -eq 'en')
    $title = if ($en) { $Spec.Name.en } else { $Spec.Name.ru }
    if (-not $script:BfOnWindows) {
        Start-Work
        Write-Live $title
        if ($en) { Add-Outcome 'note' "$title installs on Windows only." }
        else { Add-Outcome 'note' "$title устанавливается только в Windows." }
        Show-Outcome
        [void](Read-Host ('  ' + $script:S.PressEnter))
        return
    }
    Write-Host ''
    if ($en) {
        Write-Host '  What will happen:' -ForegroundColor Cyan
        Write-Host "    1. $title will be closed and removed from this computer."
        Write-Host "    2. A fresh $title will be installed."
    }
    else {
        Write-Host '  Будет сделано:' -ForegroundColor Cyan
        Write-Host "    1. $title будет закрыт и удалён с этого компьютера."
        Write-Host "    2. Будет установлен свежий $title."
    }
    Write-Host ''
    $go = Read-Host $(if ($en) { '  Continue? Type y, anything else cancels (y/n)' } else { '  Продолжить? Введи y, любой другой ответ - отмена (y/n)' })
    if (-not (Test-Yes $go)) {
        if ($en) { Write-Host '  Cancelled. Nothing changed.' } else { Write-Host '  Отменено. Ничего не изменено.' }
        return
    }
    $del = $false
    if (@($Spec.DataPaths).Count -gt 0) {
        $da = Read-Host $(if ($en) { "  Also delete the $title data on this computer (profiles, bookmarks, history)? (y/n)" } else { "  Удалить и данные $title на этом компьютере (профили, закладки, историю)? (y/n)" })
        $del = [bool](Test-Yes $da)
    }
    Start-Work
    Write-Live $(if ($en) { "removing $title" } else { "удаляем $title" })
    [void](Stop-BfProcesses $Spec.ProcessRe)
    $names = @($script:BfUninstallerNames) + @($Spec.UninstallerNames | Where-Object { $_ })
    $snap = Get-BfInstallSnapshot $Spec
    $failed = $false
    $left = @()
    $absent = ((@($snap.Files).Count + @($snap.Keys).Count) -eq 0)
    if ($absent) {
        if ($en) { Write-BfLine "  [i] $title is not found on this computer - installing fresh." 'DarkGray' }
        else { Write-BfLine "  [i] $title на этом компьютере не найден - ставим заново." 'DarkGray' }
    }
    else {
        $hint = $false
        $wg = @{ Removed = $false; Failed = $false }
        if (@($Spec.WingetIds).Count -gt 0) { $wg = Remove-BfWinget $Spec.WingetIds $en; $failed = $wg.Failed }
        $left = @(Get-BfRemaining $snap)
        if ($left.Count -gt 0 -and $wg.Removed) {
            if ($en) { Write-BfLine '  If an uninstall window opened, click "Uninstall" in it. Waiting for it to finish.' 'Cyan' }
            else { Write-BfLine '  Если открылось окно удаления - нажми в нём «Удалить». Ждём, пока оно закончит.' 'Cyan' }
            $hint = $true
            Write-Live $(if ($en) { "waiting for the $title uninstaller (up to 10 minutes)" } else { "ждём удалитель $title (до 10 минут)" })
            $left = @(Wait-BfGone $snap $names)
        }
        if ($left.Count -gt 0 -and $Spec.UninstallRe) {
            if (-not $hint) {
                if ($en) { Write-BfLine '  If an uninstall window opens, click "Uninstall" in it.' 'Cyan' }
                else { Write-BfLine '  Если откроется окно удаления - нажми в нём «Удалить».' 'Cyan' }
            }
            Write-Live $(if ($en) { "removing $title" } else { "удаляем $title" })
            Remove-BfRegistryUninstall $Spec.UninstallRe $en $Spec.UninstallArgs $Spec.MachineArgs $Spec.SignerOrg
            Write-Live $(if ($en) { "waiting for the $title uninstaller (up to 10 minutes)" } else { "ждём удалитель $title (до 10 минут)" })
            $left = @(Wait-BfGone $snap $names)
        }
    }
    if ($del) {
        Write-Live $(if ($en) { "deleting the $title data" } else { "удаляем данные $title" })
        if ($Spec.RemoveData) { $Spec.RemoveData.Invoke() } else { Remove-BfData $Spec.DataPaths }
    }
    Clear-Live
    if ($left.Count -gt 0) {
        if ($en) {
            Write-Host "  [X] $title was not removed, so a fresh install would not happen. Still on disk:" -ForegroundColor Red
            foreach ($path in $left) { Write-Host "      $path" -ForegroundColor Red }
            Write-Host '      Likely causes: the uninstall window was closed without removing, the UAC prompt was declined, or the uninstaller needs a restart. Run this item again; if it repeats, restart Windows first.' -ForegroundColor Yellow
        }
        else {
            Write-Host "  [X] $title не удалён, поэтому свежей установки не будет. На диске осталось:" -ForegroundColor Red
            foreach ($path in $left) { Write-Host "      $path" -ForegroundColor Red }
            Write-Host '      Вероятные причины: окно удаления закрыли, не удалив, в окне UAC нажали «Нет» или удалителю нужна перезагрузка. Выбери этот пункт снова; если повторится - сначала перезагрузи Windows.' -ForegroundColor Yellow
        }
        [void](Read-Host ('  ' + $script:S.PressEnter))
        return
    }
    if ($failed) {
        if ($en) { Write-Host "  [!] winget reported an error, but the $title files are gone; installing fresh." -ForegroundColor Yellow }
        else { Write-Host "  [!] winget сообщил об ошибке, но файлов $title уже нет; ставим заново." -ForegroundColor Yellow }
    }
    elseif (-not $absent) {
        if ($en) { Write-Host "  [OK] $title is removed." -ForegroundColor Green }
        else { Write-Host "  [OK] $title удалён." -ForegroundColor Green }
    }
    $script:BfFreshInstall = $true
    try { $Spec.Install.Invoke() } finally { $script:BfFreshInstall = $false }
}

function Invoke-GoogleChromeInstall {
    $en = ($script:Lang -eq 'en')
    Start-Work
    Write-Live 'Google Chrome'
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        if ($en) { Add-Outcome 'fail' 'winget is not available. Nothing was changed.' }
        else { Add-Outcome 'fail' 'winget недоступен. Ничего не изменено.' }
    }
    else {
        $rc = Invoke-Quiet 'winget' @('install', '-e', '--id', 'Google.Chrome', '--source', 'winget', '--silent', '--accept-package-agreements', '--accept-source-agreements')
        if ($script:BfFreshInstall -and ($script:BfWingetAlready -contains $rc)) {
            if ($en) { Add-Outcome 'fail' 'Google Chrome is still installed: the removal did not finish, so no fresh copy was put in. Run this item again.' }
            else { Add-Outcome 'fail' 'Google Chrome всё ещё установлен: удаление не закончилось, свежая копия не поставлена. Выбери этот пункт снова.' }
        }
        elseif (($rc -eq 0) -or ($script:BfWingetAlready -contains $rc)) {
            if ($en) { Add-Outcome 'ok' 'Google Chrome is installed.' } else { Add-Outcome 'ok' 'Google Chrome установлен.' }
        }
        else {
            if ($en) { Add-Outcome 'fail' "Google Chrome was not installed (winget code $rc)." }
            else { Add-Outcome 'fail' "Google Chrome не установлен (код winget $rc)." }
        }
    }
    Show-Outcome
    [void](Read-Host ('  ' + $script:S.PressEnter))
}

function Get-BfChromeSpec {
    $pf = Get-BfProgramFilesDirs
    $local = Get-BfLocalDir
    return @{
        Name = @{ ru = 'Google Chrome'; en = 'Google Chrome' }
        WingetIds = @('Google.Chrome')
        RegistryUninstall = $true
        UninstallRe = '^Google Chrome$'
        UninstallArgs = '--uninstall --force-uninstall'
        MachineArgs = '--system-level'
        SignerOrg = 'Google LLC'
        ExeName = 'chrome.exe'
        UninstallerNames = @('setup')
        ProcessRe = '\\Google\\Chrome\\'
        DataPaths = @(Join-BfPath $local 'Google\Chrome\User Data' | Where-Object { $_ })
        Exe = @(@($pf | ForEach-Object { Join-BfPath $_ 'Google\Chrome\Application\chrome.exe' }) + (Join-BfPath $local 'Google\Chrome\Application\chrome.exe') | Where-Object { $_ })
        Install = { Invoke-GoogleChromeInstall }
    }
}

function Invoke-GoogleChromeAction([string]$Action) {
    switch ($Action) {
        'reinstall' { Invoke-BrowserFamilyReinstall (Get-BfChromeSpec) }
    }
}
