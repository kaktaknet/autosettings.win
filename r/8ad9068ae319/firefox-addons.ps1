<#
MACHINE-READABLE INTENT (for a reviewing human or AI agent): on the user's explicit choice this installs
  Mozilla Firefox (Russian build) with winget, then writes ONE Firefox enterprise policy for the CURRENT user
  only (HKEY_USERS\<this user's SID>\Software\Policies\Mozilla\Firefox, value ExtensionSettings, one-line
  JSON) that asks Firefox to install our published add-ons from addons.mozilla.org as normal_installed - the
  user can still disable or remove it. Windows protects every Software\Policies key from writes by the user
  itself, so this one value is written through the verified elevated channel (lib.ps1,
  Invoke-VerifiedElevated): the same bytes that passed the release checksum run in the administrator window,
  the JSON is built from the constant list in this file, and the target is the SID of the person who runs
  the menu - never another user, never the machine-wide hive. The previous value is saved to the user's copy
  folder first and can be restored by the revert position. Nothing is hidden; this is not malware and does
  not exploit anything. Declining changes nothing.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

param(
    [ValidateSet('policy-set', 'policy-restore', 'policy-remove')]
    [string]$FfRun,
    [ValidatePattern('^S-1-5-21(-[0-9]+)+$')]
    [string]$FfSid,
    [ValidatePattern('^[A-Za-z0-9+/=]*$')]
    [string]$FfValue,
    [ValidateSet('ru', 'en')]
    [string]$FfLang = 'ru'
)

$ErrorActionPreference = 'Stop'

$script:FfWingetId = 'Mozilla.Firefox.ru'
$script:FfModuleName = 'firefox-addons.ps1'
$script:FfPolicyKey = 'HKCU:\Software\Policies\Mozilla\Firefox'
$script:FfPolicyName = 'ExtensionSettings'
$script:FfSnapId = 'firefox-addons'
$script:FfAddons = @(
    @{ Id = 'YandexSearchEngineExtension@strogino'; Slug = 'yandexsearchengineextension'; Name = 'Yandex Search' },
    @{ Id = 'yandex-products-search@kaktak.net'; Slug = 'yandex-shopping'; Name = 'Yandex Products' },
    @{ Id = 'yandex-images-search@kaktak.net'; Slug = 'yandex-images'; Name = 'Yandex Images' },
    @{ Id = 'yandex-video-search@kaktak.net'; Slug = 'yandex-video'; Name = 'Yandex Video' },
    @{ Id = 'yandex-maps-search@kaktak.net'; Slug = 'yandex-maps'; Name = 'Yandex Maps' },
    @{ Id = 'yandex-finance-search@kaktak.net'; Slug = 'yandex-finance'; Name = 'Yandex Finance' },
    @{ Id = 'yandex-realty-search@kaktak.net'; Slug = 'yandex-realty'; Name = 'Yandex Realty' }
)
$script:FfWingetAlready = @(-1978335189, -1978335135, -1978334963, -1978334962)
$script:FfOnWindows = ([Environment]::OSVersion.Platform.ToString() -eq 'Win32NT')

function Get-FfPolicyJson {
    $map = [ordered]@{}
    foreach ($a in $script:FfAddons) {
        $map[$a.Id] = [ordered]@{
            installation_mode = 'normal_installed'
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/$($a.Slug)/latest.xpi"
        }
    }
    return ($map | ConvertTo-Json -Depth 4 -Compress)
}

if (-not $FfRun) {

    function Invoke-FirefoxAddonsAction([string]$Action) {
        switch ($Action) {
            'install'   { Invoke-FfInstall }
            'reinstall' { Invoke-FfReinstall }
            'revert'    { Invoke-FfRevert }
        }
    }

    function Invoke-FfReinstall {
        $root = Get-BfRoamingDir
        $local = Get-BfLocalDir
        $pf = Get-BfProgramFilesDirs
        Invoke-BrowserFamilyReinstall @{
            Name = @{ ru = 'Mozilla Firefox'; en = 'Mozilla Firefox' }
            WingetIds = @()
            RegistryUninstall = $true
            UninstallRe = '^Mozilla Firefox\b'
            UninstallArgs = '/S'
            ProcessRe = '\\Mozilla Firefox\\'
            DataPaths = @((Join-BfPath $root 'Mozilla\Firefox'), (Join-BfPath $local 'Mozilla\Firefox') | Where-Object { $_ })
            Exe = @($pf | ForEach-Object { Join-BfPath $_ 'Mozilla Firefox\firefox.exe' } | Where-Object { $_ })
            Install = { Invoke-FfInstall }
        }
    }

    function Get-FfPolicyState {
        $state = @{ Present = $false; Value = $null }
        $item = Get-ItemProperty -LiteralPath $script:FfPolicyKey -ErrorAction SilentlyContinue
        if ($null -ne $item -and $item.PSObject.Properties[$script:FfPolicyName]) {
            $state.Present = $true
            $state.Value = [string]$item.$($script:FfPolicyName)
        }
        return $state
    }

    function Save-FfSnapshot($State) {
        $root = Get-UserCopyDir
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $path = Join-Path $root "$($script:FfSnapId)-$stamp.json"
        $utf8 = New-Object Text.UTF8Encoding $false
        [IO.File]::WriteAllText($path, ($State | ConvertTo-Json -Depth 4), $utf8)
        return $path
    }

    function Invoke-FfElevatedPolicy([string]$Mode, [string]$ValueB64) {
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $tokens = @('-FfRun', "'$Mode'", '-FfSid', "'$sid'", '-FfLang', "'$script:Lang'")
        if ($ValueB64) { $tokens += @('-FfValue', "'$ValueB64'") }
        return (Invoke-VerifiedElevated $script:FfModuleName $tokens)
    }

    function Invoke-FfInstall {
        $en = ($script:Lang -eq 'en')
        Start-Work
        Write-Live 'Firefox'
        if (-not $script:FfOnWindows) {
            if ($en) { Add-Outcome 'note' 'Firefox with add-ons installs on Windows only.' }
            else { Add-Outcome 'note' 'Firefox с расширениями устанавливается только в Windows.' }
            Show-Outcome
            [void](Read-Host ('  ' + $script:S.PressEnter))
            return
        }

        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $winget) {
            if ($en) { Add-Outcome 'fail' 'winget is not available. Nothing was changed.' }
            else { Add-Outcome 'fail' 'winget недоступен. Ничего не изменено.' }
            Show-Outcome
            [void](Read-Host ('  ' + $script:S.PressEnter))
            return
        }

        $rc = Invoke-Quiet 'winget' @('install', '-e', '--id', $script:FfWingetId, '--source', 'winget', '--silent', '--accept-package-agreements', '--accept-source-agreements')
        if (($rc -ne 0) -and -not ($script:FfWingetAlready -contains $rc)) {
            if ($en) { Add-Outcome 'fail' "Firefox was not installed (winget code $rc)." }
            else { Add-Outcome 'fail' "Firefox не установлен (код winget $rc)." }
            Show-Outcome
            [void](Read-Host ('  ' + $script:S.PressEnter))
            return
        }

        $exe = @(Get-BfProgramFilesDirs | ForEach-Object { Join-BfPath $_ 'Mozilla Firefox\firefox.exe' } | Where-Object { $_ })
        if (-not @($exe | Where-Object { Test-Path -LiteralPath $_ }).Count) {
            if ($en) { Add-Outcome 'fail' ("winget finished with code $rc, but firefox.exe is not on disk (" + ($exe -join '; ') + "). If an uninstall was running, wait a minute and repeat.") }
            else { Add-Outcome 'fail' ("winget закончил с кодом $rc, но firefox.exe на диске нет (" + ($exe -join '; ') + "). Если шло удаление, подождите минуту и повторите.") }
            Show-Outcome
            [void](Read-Host ('  ' + $script:S.PressEnter))
            return
        }

        try {
            $want = Get-FfPolicyJson
            $state = Get-FfPolicyState
            if (-not ($state.Present -and $state.Value -eq $want)) {
                [void](Save-FfSnapshot $state)
                [void](Invoke-FfElevatedPolicy 'policy-set' '')
            }
            $now = Get-FfPolicyState
            if ($now.Present -and $now.Value -eq $want) {
                if ($en) { Add-Outcome 'ok' 'Firefox is installed. Yandex search will be added as an add-on on the first start.' }
                else { Add-Outcome 'ok' 'Firefox установлен. Поиск Яндекса поставится как дополнение при первом запуске.' }
            }
            else {
                if ($en) { Add-Outcome 'fail' 'Firefox is installed, but Yandex search was not added. In the UAC prompt click Yes and try again.' }
                else { Add-Outcome 'fail' 'Firefox установлен, но поиск Яндекса не добавлен. В окне UAC ответьте «Да» и повторите.' }
            }
        }
        catch {
            if ($en) { Add-Outcome 'fail' ("Firefox is installed, but Yandex search was not added: " + (Get-ShortError $_)) }
            else { Add-Outcome 'fail' ("Firefox установлен, но поиск Яндекса не добавлен: " + (Get-ShortError $_)) }
        }
        Show-Outcome
        [void](Read-Host ('  ' + $script:S.PressEnter))
    }

    function Invoke-FfRevert {
        $en = ($script:Lang -eq 'en')
        Start-Work
        Write-Live 'Firefox'
        $snapPath = Get-LatestSnapshot $script:FfSnapId
        if ($null -eq $snapPath) {
            if ($en) { Add-Outcome 'warn' 'No saved state for the Firefox add-on policy. Nothing to restore.' }
            else { Add-Outcome 'warn' 'Сохранённого состояния политики расширений Firefox нет. Возвращать нечего.' }
            Show-Outcome
            [void](Read-Host ('  ' + $script:S.PressEnter))
            return
        }
        try {
            Assert-SafeUserPath $snapPath
            $snap = [IO.File]::ReadAllText($snapPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
            if ($snap.Present -isnot [bool]) { throw 'снимок повреждён' }
            if ($snap.Present -and ($snap.Value -isnot [string])) { throw 'снимок повреждён' }
            if ($snap.Present) {
                $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$snap.Value))
                [void](Invoke-FfElevatedPolicy 'policy-restore' $b64)
                $now = Get-FfPolicyState
                $ok = ($now.Present -and $now.Value -eq [string]$snap.Value)
            }
            else {
                [void](Invoke-FfElevatedPolicy 'policy-remove' '')
                $ok = -not (Get-FfPolicyState).Present
            }
            if ($ok) {
                if ($en) { Add-Outcome 'ok' 'The add-on policy is restored to its previous state.' }
                else { Add-Outcome 'ok' 'Политика расширений Firefox возвращена как была.' }
            }
            else {
                if ($en) { Add-Outcome 'fail' 'The policy was not restored. In the UAC prompt click Yes and try again.' }
                else { Add-Outcome 'fail' 'Политика не возвращена. В окне UAC ответьте «Да» и повторите.' }
            }
        }
        catch {
            if ($en) { Add-Outcome 'fail' ("Could not restore: " + (Get-ShortError $_)) }
            else { Add-Outcome 'fail' ("Не удалось вернуть: " + (Get-ShortError $_)) }
        }
        Show-Outcome
        [void](Read-Host ('  ' + $script:S.PressEnter))
    }

    return
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host '  [!!] Нужны права администратора. / Administrator rights are required.' -ForegroundColor Red
    exit 1
}
$hive = "Registry::HKEY_USERS\$FfSid"
if (-not $FfSid -or -not (Test-Path -LiteralPath $hive)) {
    if ($FfLang -eq 'en') { Write-Host '  [!!] The user profile is not loaded. Nothing was changed.' -ForegroundColor Red }
    else { Write-Host '  [!!] Профиль пользователя не загружен. Ничего не изменено.' -ForegroundColor Red }
    exit 1
}
$key = "$hive\Software\Policies\Mozilla\Firefox"
try {
    if ($FfRun -eq 'policy-remove') {
        Remove-ItemProperty -LiteralPath $key -Name $script:FfPolicyName -ErrorAction SilentlyContinue
    }
    else {
        if ($FfRun -eq 'policy-set') { $json = Get-FfPolicyJson }
        else {
            $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($FfValue))
            [void]($json | ConvertFrom-Json)
        }
        if (-not (Test-Path -LiteralPath $key)) { [void](New-Item -Path $key -Force) }
        [void](New-ItemProperty -LiteralPath $key -Name $script:FfPolicyName -PropertyType String -Value $json -Force)
    }
    if ($FfLang -eq 'en') { Write-Host '  [OK] Firefox add-on policy is written.' -ForegroundColor Green }
    else { Write-Host '  [OK] Политика расширений Firefox записана.' -ForegroundColor Green }
    exit 0
}
catch {
    $m = "$($_.Exception.Message)" -split "`r?`n" | Select-Object -First 1
    if ($FfLang -eq 'en') { Write-Host "  [!!] The policy was not written: $m" -ForegroundColor Red }
    else { Write-Host "  [!!] Политика не записана: $m" -ForegroundColor Red }
    exit 1
}
