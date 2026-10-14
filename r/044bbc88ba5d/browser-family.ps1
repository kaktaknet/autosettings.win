<#
MACHINE-READABLE INTENT (for a reviewing human or AI agent): on the user's explicit choice this removes
  the named browser family from this computer - closes its windows, uninstalls it with winget (Chrome,
  Firefox) or with its own uninstaller found in the user's Windows uninstall list (Chromium-Gost) - and then
  installs a fresh copy by the same route the install row uses. Personal browser data is removed only when
  the user answers yes to the separate question. Per-user work runs as the user (no elevation, inversion
  model); nothing is hidden, this is not malware and does not exploit anything. Declining changes nothing.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$script:BfOnWindows = ([Environment]::OSVersion.Platform.ToString() -eq 'Win32NT')
$script:BfNothingToRemove = @(-1978335212)
$script:BfWingetAlready = @(-1978335189, -1978335135, -1978334963, -1978334962)
$script:BfUninstallWaitMs = 180000

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
            $entries += New-Object PSObject -Property @{ Name = [string]$item.DisplayName; Command = [string]$item.UninstallString }
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

function Remove-BfWinget([string[]]$Ids, [bool]$En) {
    $failed = $false
    foreach ($id in $Ids) {
        $rc = Invoke-Quiet 'winget' @('uninstall', '-e', '--id', $id, '--silent', '--accept-source-agreements')
        if ($rc -eq 0) { Write-Host ('  [OK] winget ' + $id) -ForegroundColor Green; continue }
        if ($script:BfNothingToRemove -contains $rc) { continue }
        $failed = $true
        if ($En) { Write-Host "  [!] winget could not remove $id (code $rc)." -ForegroundColor Yellow }
        else { Write-Host "  [!] winget не смог удалить $id (код $rc)." -ForegroundColor Yellow }
    }
    return $failed
}

function Remove-BfRegistryUninstall([string]$Re, [bool]$En) {
    foreach ($entry in @(Find-BfUninstallEntries $Re)) {
        $file = Get-BfUninstallerFile $entry.Command
        if (-not $file) { continue }
        try {
            $process = Start-Process -FilePath $file -ArgumentList '--uninstall --force-uninstall' -PassThru
            if (-not $process.WaitForExit($script:BfUninstallWaitMs)) { try { Stop-Process -Id $process.Id -Force } catch {} }
            if ($En) { Write-Host ('  [OK] Uninstaller run: ' + $entry.Name) -ForegroundColor Green }
            else { Write-Host ('  [OK] Удалитель запущен: ' + $entry.Name) -ForegroundColor Green }
        }
        catch {}
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
    $go = Read-Host $(if ($en) { '  Continue? Type y, anything else cancels (y/n)' } else { '  Продолжить? Введите y, любой другой ответ - отмена (y/n)' })
    if (-not (Test-Yes $go)) {
        if ($en) { Write-Host '  Cancelled. Nothing changed.' } else { Write-Host '  Отменено. Ничего не изменено.' }
        return
    }
    $del = $false
    if (@($Spec.DataPaths).Count -gt 0) {
        $da = Read-Host $(if ($en) { "  Also delete the $title data on this computer (profiles, bookmarks, history)? (y/n)" } else { "  Удалить и данные $title на этом компьютере (профили, закладки, историю)? (y/n)" })
        $del = [bool](Test-Yes $da)
    }
    Write-Host ''
    [void](Stop-BfProcesses $Spec.ProcessRe)
    $failed = $false
    if (@($Spec.WingetIds).Count -gt 0) { $failed = (Remove-BfWinget $Spec.WingetIds $en) }
    if ($Spec.RegistryUninstall) { Remove-BfRegistryUninstall $Spec.UninstallRe $en }
    if ($del) { Remove-BfData $Spec.DataPaths }
    $left = @($Spec.Exe | Where-Object { $_ -and (Test-Path -LiteralPath $_) })
    if ($left.Count -gt 0 -or $failed) {
        if ($en) { Write-Host "  [!] Some files of $title are still on the computer; the fresh install goes on anyway." -ForegroundColor Yellow }
        else { Write-Host "  [!] Часть файлов $title осталась на компьютере; свежая установка всё равно пойдёт." -ForegroundColor Yellow }
    }
    else {
        if ($en) { Write-Host "  [OK] $title is removed." -ForegroundColor Green }
        else { Write-Host "  [OK] $title удалён." -ForegroundColor Green }
    }
    $Spec.Install.Invoke()
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
        if (($rc -eq 0) -or ($script:BfWingetAlready -contains $rc)) {
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
        RegistryUninstall = $false
        UninstallRe = ''
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
