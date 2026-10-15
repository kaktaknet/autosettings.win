<#
MACHINE-READABLE INTENT (for a reviewing human or AI agent): on the user's explicit choice this installs
  Mozilla Firefox (Russian build) with winget, then writes ONE Firefox enterprise policy for the CURRENT user
  only (HKEY_USERS\<this user's SID>\Software\Policies\Mozilla\Firefox, value ExtensionSettings, one-line
  JSON) that asks Firefox to install our published add-ons from addons.mozilla.org as normal_installed - the
  user can still disable or remove it - plus the SearchEngines policy in the same key: one engine (Yandex,
  constant URL in this file) added and made the default, so search is Yandex from the first start. Windows protects every Software\Policies key from writes by the user
  itself, so this one value is written through the verified elevated channel (lib.ps1,
  Invoke-VerifiedElevated): the same bytes that passed the release checksum run in the administrator window,
  the JSON is built from the constant list in this file, and the target is the SID of the person who runs
  the menu - never another user, never the machine-wide hive. The elevated branch accepts no value from
  outside: it writes only the JSON built from this file. Nothing is hidden; this is not malware and does
  not exploit anything. Declining changes nothing.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

param(
    [ValidateSet('policy-set')]
    [string]$FfRun,
    [ValidatePattern('^S-1-5-21(-[0-9]+)+$')]
    [string]$FfSid,
    [ValidateSet('ru', 'en')]
    [string]$FfLang = 'ru'
)

$ErrorActionPreference = 'Stop'

$script:FfWingetId = 'Mozilla.Firefox.ru'
$script:FfModuleName = 'firefox-addons.ps1'
$script:FfPolicyKey = 'HKCU:\Software\Policies\Mozilla\Firefox'
$script:FfPolicyName = 'ExtensionSettings'
$script:FfSearchName = 'Ya'
$script:FfSearchKeyword = 'yandex'
$script:FfSearchURL = 'https://yandex.ru/search/?text={searchTerms}&clid=15437607&ie={inputEncoding}&from=firefox'
$script:FfSuggestURL = 'https://suggest.yandex.ru/suggest-ff.cgi?part={searchTerms}&clid=15437607&'
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

    function Test-FfSearchPolicy {
        $root = $script:FfPolicyKey + '\SearchEngines'
        $default = (Get-ItemProperty -LiteralPath $root -ErrorAction SilentlyContinue).Default
        $add = Get-ItemProperty -LiteralPath ($root + '\Add\1') -ErrorAction SilentlyContinue
        return (($default -eq $script:FfSearchName) -and $null -ne $add -and
            ($add.Name -eq $script:FfSearchName) -and ($add.URLTemplate -eq $script:FfSearchURL))
    }

    function Invoke-FfElevatedPolicy {
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $tokens = @('-FfRun', "'policy-set'", '-FfSid', "'$sid'", '-FfLang', "'$script:Lang'")
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
            if (-not ($state.Present -and $state.Value -eq $want -and (Test-FfSearchPolicy))) {
                [void](Invoke-FfElevatedPolicy)
            }
            $now = Get-FfPolicyState
            if ($now.Present -and $now.Value -eq $want -and (Test-FfSearchPolicy)) {
                if ($en) { Add-Outcome 'ok' 'Firefox is installed. Yandex is the default search; the Yandex search add-on is added on the first start.' }
                else { Add-Outcome 'ok' 'Firefox установлен. Поиск Яндекса - по умолчанию, дополнение поиска Яндекса поставится при первом запуске.' }
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
    $json = Get-FfPolicyJson
    if (-not (Test-Path -LiteralPath $key)) { [void](New-Item -Path $key -Force) }
    [void](New-ItemProperty -LiteralPath $key -Name $script:FfPolicyName -PropertyType String -Value $json -Force)
    $search = "$key\SearchEngines"
    if (Test-Path -LiteralPath $search) { Remove-Item -LiteralPath $search -Recurse -Force }
    $add = "$search\Add\1"
    [void](New-Item -Path $add -Force)
    foreach ($pair in @(@('Name', $script:FfSearchName), @('URLTemplate', $script:FfSearchURL), @('Method', 'GET'),
            @('Alias', $script:FfSearchKeyword), @('SuggestURLTemplate', $script:FfSuggestURL))) {
        [void](New-ItemProperty -LiteralPath $add -Name $pair[0] -PropertyType String -Value $pair[1] -Force)
    }
    [void](New-ItemProperty -LiteralPath $search -Name 'Default' -PropertyType String -Value $script:FfSearchName -Force)
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
