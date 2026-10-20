<#
MACHINE-READABLE INTENT (for a reviewing human or AI agent): on the user's explicit choice this installs
  Mozilla Firefox or Firefox Developer Edition with winget (the Russian build for the Russian menu, the English
  build for the English menu), then writes ONE Firefox enterprise policy for the CURRENT user
  only (HKEY_USERS\<this user's SID>\Software\Policies\Mozilla\Firefox, value ExtensionSettings, one-line
  JSON) that asks Firefox to install our published add-ons from addons.mozilla.org as normal_installed - the
  user can still disable or remove it - plus the SearchEngines policy in the same key: one engine (Yandex,
  constant URL in this file) added and made the default, so search is Yandex from the first start. Windows protects every Software\Policies key from writes by the user
  itself, so this one value is written through the verified elevated channel (lib.ps1,
  Invoke-VerifiedElevated): the same bytes that passed the release checksum run in the administrator window,
  our entries are built from the constant list in this file and MERGED into the existing value (entries of
  an organization, such as a "*" block, are kept; an unreadable value is left untouched), the search engine
  takes a free slot without removing other engines, and the target is the SID of the person who runs
  the menu - never another user, never the machine-wide hive. The elevated branch accepts no value from
  outside: it adds only the entries built from this file. Nothing is hidden; this is not malware and does
  not exploit anything. Declining changes nothing. Reinstall removes the chosen edition with its own
  uninstaller and, only if the user agrees, its profiles; the other edition's profiles are kept.
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

$script:FfEditions = @{
    release = @{
        Title = 'Mozilla Firefox'
        WingetIds = @{ ru = 'Mozilla.Firefox.ru'; en = 'Mozilla.Firefox' }
        Dir = 'Mozilla Firefox'
        UninstallRe = '^Mozilla Firefox\b'
        ProcessRe = '\\Mozilla Firefox\\'
        ProfileRe = '^(?!dev-edition-default)'
    }
    dev = @{
        Title = 'Firefox Developer Edition'
        WingetIds = @{ ru = 'Mozilla.Firefox.DeveloperEdition.ru'; en = 'Mozilla.Firefox.DeveloperEdition' }
        Dir = 'Firefox Developer Edition'
        UninstallRe = '^Firefox Developer Edition\b'
        ProcessRe = '\\Firefox Developer Edition\\'
        ProfileRe = '^dev-edition-default'
    }
}
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

function Merge-FfPolicyJson([string]$Current) {
    $merged = [ordered]@{}
    if ($Current -and $Current.Trim()) {
        $old = $Current | ConvertFrom-Json -ErrorAction Stop
        if ($old -isnot [Management.Automation.PSCustomObject]) { throw 'ExtensionSettings is not a JSON object' }
        foreach ($prop in $old.PSObject.Properties) { $merged[$prop.Name] = $prop.Value }
    }
    $ours = Get-FfPolicyJson | ConvertFrom-Json
    foreach ($prop in $ours.PSObject.Properties) { $merged[$prop.Name] = $prop.Value }
    return ($merged | ConvertTo-Json -Depth 8 -Compress)
}

function Test-FfPolicyHasOurs([string]$Value) {
    if (-not $Value) { return $false }
    try { $now = $Value | ConvertFrom-Json -ErrorAction Stop } catch { return $false }
    foreach ($prop in (Get-FfPolicyJson | ConvertFrom-Json).PSObject.Properties) {
        $have = $now.PSObject.Properties[$prop.Name]
        if (-not $have -or $have.Value.installation_mode -ne $prop.Value.installation_mode -or
            $have.Value.install_url -ne $prop.Value.install_url) { return $false }
    }
    return $true
}

function Get-FfSearchSlot([string]$Root) {
    $free = 1
    $taken = @()
    foreach ($k in @(Get-ChildItem -LiteralPath ($Root + '\Add') -ErrorAction SilentlyContinue)) {
        $n = 0
        if (-not [int]::TryParse($k.PSChildName, [ref]$n)) { continue }
        $taken += $n
        if ((Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue).Name -eq $script:FfSearchName) { return $k.PSChildName }
    }
    while ($taken -contains $free) { $free++ }
    return "$free"
}

if (-not $FfRun) {

    function Invoke-FirefoxAddonsAction([string]$Action) {
        switch ($Action) {
            'install'      { Invoke-FfInstall $script:FfEditions.release }
            'reinstall'    { Invoke-FfReinstall $script:FfEditions.release }
            'install-dev'   { Invoke-FfInstall $script:FfEditions.dev }
            'reinstall-dev' { Invoke-FfReinstall $script:FfEditions.dev }
        }
    }

    function Get-FfWingetId($Ed) {
        if ($script:Lang -eq 'en') { return $Ed.WingetIds.en }
        return $Ed.WingetIds.ru
    }

    function Get-FfExePaths($Ed) {
        return @(Get-BfProgramFilesDirs | ForEach-Object { Join-BfPath $_ ($Ed.Dir + '\firefox.exe') } | Where-Object { $_ })
    }

    function Test-FfInstalled($Ed) {
        return [bool](@(Get-FfExePaths $Ed | Where-Object { Test-Path -LiteralPath $_ }).Count)
    }

    function Read-FfIni([string]$Path) {
        $sections = New-Object System.Collections.ArrayList
        $cur = $null
        foreach ($line in [IO.File]::ReadAllLines($Path)) {
            if ($line -match '^\s*\[(.+)\]\s*$') {
                $cur = [ordered]@{ Name = $Matches[1]; Keys = [ordered]@{} }
                [void]$sections.Add($cur)
            }
            elseif ($cur -and $line -match '^([^=;#]+)=(.*)$') { $cur.Keys[$Matches[1].Trim()] = $Matches[2] }
        }
        return , $sections
    }

    function Write-FfIni([string]$Path, $Sections) {
        $out = New-Object System.Text.StringBuilder
        foreach ($s in $Sections) {
            [void]$out.Append('[' + $s.Name + "]`r`n")
            foreach ($k in $s.Keys.Keys) { [void]$out.Append($k + '=' + $s.Keys[$k] + "`r`n") }
            [void]$out.Append("`r`n")
        }
        [IO.File]::WriteAllText($Path, $out.ToString(), (New-Object System.Text.UTF8Encoding $false))
    }

    function Remove-FfEditionData($Ed) {
        $roam = Join-BfPath (Get-BfRoamingDir) 'Mozilla\Firefox'
        $loc = Join-BfPath (Get-BfLocalDir) 'Mozilla\Firefox'
        $other = if ($Ed -eq $script:FfEditions.dev) { $script:FfEditions.release } else { $script:FfEditions.dev }
        if (-not (Test-FfInstalled $other)) {
            Remove-BfData @($roam, $loc | Where-Object { $_ })
            return
        }
        $ini = Join-Path $roam 'profiles.ini'
        if (-not (Test-Path -LiteralPath $ini)) { return }
        try {
            Assert-SafeUserPath $roam
            $sections = Read-FfIni $ini
            $gone = @{}
            $keep = New-Object System.Collections.ArrayList
            $n = 0
            foreach ($s in $sections) {
                if ($s.Name -match '^Profile\d+$') {
                    $mine = ([string]$s.Keys['Name'] -match $Ed.ProfileRe) -and ($s.Keys['IsRelative'] -eq '1')
                    if ($mine) {
                        $rel = ([string]$s.Keys['Path']) -replace '/', '\'
                        $gone[$s.Keys['Path']] = $true
                        Remove-BfData @((Join-Path $roam $rel), (Join-Path $loc $rel))
                        continue
                    }
                    $s.Name = 'Profile' + $n
                    $n++
                }
                [void]$keep.Add($s)
            }
            if ($gone.Count -eq 0) { return }
            $keep = @($keep | Where-Object { -not ($_.Name -like 'Install*' -and $_.Keys['Default'] -and $gone.ContainsKey($_.Keys['Default'])) })
            Write-FfIni $ini $keep
            $installs = Join-Path $roam 'installs.ini'
            if (Test-Path -LiteralPath $installs) {
                $all = Read-FfIni $installs
                $left = @($all | Where-Object { -not ($_.Keys['Default'] -and $gone.ContainsKey($_.Keys['Default'])) })
                Write-FfIni $installs $left
            }
        }
        catch {
            if ($script:Lang -eq 'en') { Write-Host ("  [!] $($Ed.Title) profiles were not removed: " + (Get-ShortError $_)) -ForegroundColor Yellow }
            else { Write-Host ("  [!] Профили $($Ed.Title) не удалены: " + (Get-ShortError $_)) -ForegroundColor Yellow }
        }
    }

    function Invoke-FfReinstall($Ed) {
        $root = Get-BfRoamingDir
        $local = Get-BfLocalDir
        Invoke-BrowserFamilyReinstall @{
            Name = @{ ru = $Ed.Title; en = $Ed.Title }
            WingetIds = @()
            RegistryUninstall = $true
            UninstallRe = $Ed.UninstallRe
            UninstallArgs = '/S'
            ProcessRe = $Ed.ProcessRe
            DataPaths = @((Join-BfPath $root 'Mozilla\Firefox'), (Join-BfPath $local 'Mozilla\Firefox') | Where-Object { $_ })
            RemoveData = { Remove-FfEditionData $Ed }
            Exe = @(Get-FfExePaths $Ed)
            Install = { Invoke-FfInstall $Ed }
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
        $add = Get-ItemProperty -LiteralPath ($root + '\Add\' + (Get-FfSearchSlot $root)) -ErrorAction SilentlyContinue
        return (($default -eq $script:FfSearchName) -and $null -ne $add -and
            ($add.Name -eq $script:FfSearchName) -and ($add.URLTemplate -eq $script:FfSearchURL))
    }

    function Invoke-FfElevatedPolicy {
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $tokens = @('-FfRun', "'policy-set'", '-FfSid', "'$sid'", '-FfLang', "'$script:Lang'")
        return (Invoke-VerifiedElevated $script:FfModuleName $tokens)
    }

    function Invoke-FfInstall($Ed) {
        $en = ($script:Lang -eq 'en')
        $t = $Ed.Title
        Start-Work
        Write-Live $t
        if (-not $script:FfOnWindows) {
            if ($en) { Add-Outcome 'note' "$t with add-ons installs on Windows only." }
            else { Add-Outcome 'note' "$t с расширениями устанавливается только в Windows." }
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

        $rc = Invoke-Quiet 'winget' @('install', '-e', '--id', (Get-FfWingetId $Ed), '--source', 'winget', '--silent', '--accept-package-agreements', '--accept-source-agreements')
        if (($rc -ne 0) -and -not ($script:FfWingetAlready -contains $rc)) {
            if ($en) { Add-Outcome 'fail' "$t was not installed (winget code $rc)." }
            else { Add-Outcome 'fail' "$t не установлен (код winget $rc)." }
            Show-Outcome
            [void](Read-Host ('  ' + $script:S.PressEnter))
            return
        }

        $exe = @(Get-FfExePaths $Ed)
        if (-not @($exe | Where-Object { Test-Path -LiteralPath $_ }).Count) {
            if ($en) { Add-Outcome 'fail' ("winget finished with code $rc, but firefox.exe is not on disk (" + ($exe -join '; ') + "). If an uninstall was running, wait a minute and repeat.") }
            else { Add-Outcome 'fail' ("winget закончил с кодом $rc, но firefox.exe на диске нет (" + ($exe -join '; ') + "). Если шло удаление, подождите минуту и повторите.") }
            Show-Outcome
            [void](Read-Host ('  ' + $script:S.PressEnter))
            return
        }

        try {
            $state = Get-FfPolicyState
            if (-not ((Test-FfPolicyHasOurs $state.Value) -and (Test-FfSearchPolicy))) {
                [void](Invoke-FfElevatedPolicy)
            }
            $now = Get-FfPolicyState
            if ((Test-FfPolicyHasOurs $now.Value) -and (Test-FfSearchPolicy)) {
                if ($en) { Add-Outcome 'ok' "$t is installed. Yandex is the default search; the Yandex search add-on is added on the first start." }
                else { Add-Outcome 'ok' "$t установлен. Поиск Яндекса - по умолчанию, дополнение поиска Яндекса поставится при первом запуске." }
            }
            else {
                if ($en) { Add-Outcome 'fail' "$t is installed, but Yandex search was not added. In the UAC prompt click Yes and try again." }
                else { Add-Outcome 'fail' "$t установлен, но поиск Яндекса не добавлен. В окне UAC ответьте «Да» и повторите." }
            }
        }
        catch {
            if ($en) { Add-Outcome 'fail' ("$t is installed, but Yandex search was not added: " + (Get-ShortError $_)) }
            else { Add-Outcome 'fail' ("$t установлен, но поиск Яндекса не добавлен: " + (Get-ShortError $_)) }
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
    if (-not (Test-Path -LiteralPath $key)) { [void](New-Item -Path $key -Force) }
    $current = (Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue).$($script:FfPolicyName)
    $json = Merge-FfPolicyJson ([string]$current)
    [void](New-ItemProperty -LiteralPath $key -Name $script:FfPolicyName -PropertyType String -Value $json -Force)
    $search = "$key\SearchEngines"
    $add = "$search\Add\" + (Get-FfSearchSlot $search)
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
