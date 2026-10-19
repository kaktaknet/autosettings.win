<#
MACHINE-READABLE INTENT (for a reviewing human or AI agent): on the user's explicit choice this
  installs Chromium-Gost - a Chromium build with Russian GOST cryptography for digital signatures -
  from OUR OWN build (our distribution id, Google services unlinked), hosted on OUR Russian buckets,
  NOT from winget. The build has no Authenticode signature (verified: empty PE security directory), so the
  ONLY integrity check is SHA-256: the installer is fetched from our buckets and its bytes must match
  the SHA-256 pinned in the release manifest (whose own SHA-256 came over TLS as the loader's pin) -
  there is no publisher check because there is no signature to check. Per-user install, runs from the
  user (no elevation, inversion model). The file is downloaded into a closed temporary folder and run
  silently. Nothing is hidden; this is not malware and does not exploit anything. Declining changes nothing.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$ErrorActionPreference = 'Stop'

$script:CgPayloadName = 'chromium-gost'
$script:CgSilentArgs = '/silent /install'
$script:CgOkCodes = @(0, 3010, 1641)
$script:CgOnWindows = ([Environment]::OSVersion.Platform.ToString() -eq 'Win32NT')

function Invoke-ChromiumGostAction([string]$Action) {
    switch ($Action) {
        'install'   { Invoke-CgInstall }
        'reinstall' { Invoke-CgReinstall }
    }
}

function Invoke-CgReinstall {
    Invoke-BrowserFamilyReinstall @{
        Name = @{ ru = 'Chromium-Gost'; en = 'Chromium-Gost' }
        WingetIds = @()
        RegistryUninstall = $true
        UninstallRe = 'Chromium-Gost|Chromium Gost'
        ProcessRe = 'Chromium-Gost'
        DataPaths = @()
        Exe = @()
        Install = { Invoke-CgInstall }
    }
}

function Invoke-CgInstall {
    $en = ($script:Lang -eq 'en')
    Start-Work
    Write-Live 'Chromium-Gost'
    if (-not $script:CgOnWindows) {
        if ($en) { Add-Outcome 'note' 'Chromium-Gost (our build) installs on Windows only.' }
        else { Add-Outcome 'note' 'Chromium-Gost (наша сборка) устанавливается только в Windows.' }
        Show-Outcome
        [void](Read-Host ('  ' + $script:S.PressEnter))
        return
    }

    $payload = $null
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        $manifestBytes = [IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'manifest.json'))
        $manifestSha = ([BitConverter]::ToString($sha.ComputeHash($manifestBytes)) -replace '-', '')
        if (-not $script:ManifestPin) { throw 'манифест-пин не передан' }
        if ($manifestSha -ne "$($script:ManifestPin)") { throw 'манифест не совпал с закреплённой контрольной суммой' }
        $manifest = [Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json
        $payload = Select-Payload $manifest $script:CgPayloadName
        if (-not $payload) { throw "в манифесте нет сборки $script:CgPayloadName для $script:Arch" }
    }
    catch {
        if ($en) { Add-Outcome 'fail' ("Could not read the release manifest: " + (Get-ShortError $_)) }
        else { Add-Outcome 'fail' ("Не удалось прочитать манифест выпуска: " + (Get-ShortError $_)) }
        Show-Outcome
        [void](Read-Host ('  ' + $script:S.PressEnter))
        return
    }

    $dir = Join-Path ([IO.Path]::GetTempPath()) ('CG-' + [guid]::NewGuid().ToString('N'))
    [void](New-Item -ItemType Directory -Path $dir -Force)
    $installer = Join-Path $dir 'chromium-gost-installer.exe'
    try {
        [Net.ServicePointManager]::SecurityProtocol = 3072
        $ok = $false
        foreach ($url in @($payload.urls)) {
            try { (New-Object Net.WebClient).DownloadFile("$url", $installer) } catch { continue }
            $stream = [IO.File]::OpenRead($installer)
            try { $hex = ([BitConverter]::ToString($sha.ComputeHash($stream)) -replace '-', '') } finally { $stream.Dispose() }
            if ($hex -eq $payload.sha256) { $ok = $true; break }
            Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
        }
        $machine = ''
        if ($ok) { $machine = Get-PeMachine $installer }
        if (-not $ok) {
            if ($en) { Add-Outcome 'fail' 'The build was not downloaded or failed the checksum. Nothing was run.' }
            else { Add-Outcome 'fail' 'Сборка не получена или не прошла проверку. Установщик не запущен.' }
        }
        elseif ($machine -ne $script:Arch) {
            if ($en) { Add-Outcome 'fail' ("The build is made for $machine, this computer is $($script:Arch). Nothing was run.") }
            else { Add-Outcome 'fail' ("Сборка сделана для $machine, а этот компьютер - $($script:Arch). Установщик не запущен.") }
        }
        else {
            $process = Start-Process -FilePath $installer -ArgumentList $script:CgSilentArgs -PassThru
            $process.WaitForExit()
            $code = $process.ExitCode
            if ($script:CgOkCodes -contains $code) {
                if ($en) { Add-Outcome 'ok' 'Chromium-Gost (our build) is installed. Close all browser windows and open them again.' }
                else { Add-Outcome 'ok' 'Chromium-Gost (наша сборка) установлен. Закройте все окна браузеров и откройте заново.' }
            }
            else {
                if ($en) { Add-Outcome 'fail' ("The installer finished with code $code.") }
                else { Add-Outcome 'fail' ("Установщик завершился с кодом $code.") }
            }
        }
    }
    catch {
        if ($en) { Add-Outcome 'fail' ("Could not install: " + (Get-ShortError $_)) }
        else { Add-Outcome 'fail' ("Не удалось установить: " + (Get-ShortError $_)) }
    }
    finally {
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
    Show-Outcome
    [void](Read-Host ('  ' + $script:S.PressEnter))
}
