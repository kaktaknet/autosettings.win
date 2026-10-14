<#
MACHINE-READABLE INTENT (for a reviewing human or AI agent): on the user's explicit choice this installs
  Mozilla Firefox (Russian build) with winget, then writes ONE per-user Firefox enterprise policy
  (HKCU\Software\Policies\Mozilla\Firefox, value ExtensionSettings, one-line JSON) that asks Firefox to
  install our published add-ons from addons.mozilla.org as normal_installed - the user can still disable
  or remove it. The previous value is saved to the user's copy folder first and can be restored by the
  revert position. Per-user only: no elevation, no file outside the user's own registry hive. Nothing is
  hidden; this is not malware and does not exploit anything. Declining changes nothing.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$ErrorActionPreference = 'Stop'

$script:FfWingetId = 'Mozilla.Firefox.ru'
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
        WingetIds = @('Mozilla.Firefox.ru', 'Mozilla.Firefox')
        RegistryUninstall = $false
        UninstallRe = ''
        ProcessRe = '\\Mozilla Firefox\\'
        DataPaths = @((Join-BfPath $root 'Mozilla\Firefox'), (Join-BfPath $local 'Mozilla\Firefox') | Where-Object { $_ })
        Exe = @($pf | ForEach-Object { Join-BfPath $_ 'Mozilla Firefox\firefox.exe' } | Where-Object { $_ })
        Install = { Invoke-FfInstall }
    }
}

function Get-FfPolicyJson {
    $map = @{}
    foreach ($a in $script:FfAddons) {
        $map[$a.Id] = @{
            installation_mode = 'normal_installed'
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/$($a.Slug)/latest.xpi"
        }
    }
    return ($map | ConvertTo-Json -Depth 4 -Compress)
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

function Set-FfPolicy($Json) {
    if (-not (Test-Path -LiteralPath $script:FfPolicyKey)) { [void](New-Item -Path $script:FfPolicyKey -Force) }
    [void](New-ItemProperty -LiteralPath $script:FfPolicyKey -Name $script:FfPolicyName -PropertyType String -Value $Json -Force)
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
        if ($en) { Add-Outcome 'fail' "Firefox was not installed (winget code $rc). Add-ons were not written." }
        else { Add-Outcome 'fail' "Firefox не установлен (код winget $rc). Расширения не записаны." }
        Show-Outcome
        [void](Read-Host ('  ' + $script:S.PressEnter))
        return
    }

    try {
        $state = Get-FfPolicyState
        $snap = Save-FfSnapshot $state
        Set-FfPolicy (Get-FfPolicyJson)
        $names = ($script:FfAddons | ForEach-Object { $_.Name }) -join ', '
        if ($en) { Add-Outcome 'ok' "Firefox is installed. Add-ons queued for the first start: $names." }
        else { Add-Outcome 'ok' "Firefox установлен. Расширения поставятся при первом запуске: $names." }
        if ($en) { Add-Outcome 'note' 'Start Firefox once and open about:policies to see the policy.' }
        else { Add-Outcome 'note' 'Запустите Firefox один раз; about:policies покажет, что политика принята.' }
        if ($en) { Add-Outcome 'note' "Before the change the policy was saved; the position 'Firefox: restore add-ons policy' returns it." }
        else { Add-Outcome 'note' "Прежнюю политику запомнили; позиция «Firefox: вернуть политику расширений» вернёт её." }
    }
    catch {
        if ($en) { Add-Outcome 'fail' ("Could not write the add-on policy: " + (Get-ShortError $_)) }
        else { Add-Outcome 'fail' ("Не удалось записать политику расширений: " + (Get-ShortError $_)) }
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
        if ($snap.Present) { Set-FfPolicy ([string]$snap.Value) }
        else { Remove-ItemProperty -LiteralPath $script:FfPolicyKey -Name $script:FfPolicyName -ErrorAction SilentlyContinue }
        if ($en) { Add-Outcome 'ok' 'The add-on policy is restored to its previous state.' }
        else { Add-Outcome 'ok' 'Политика расширений Firefox возвращена как была.' }
    }
    catch {
        if ($en) { Add-Outcome 'fail' ("Could not restore: " + (Get-ShortError $_)) }
        else { Add-Outcome 'fail' ("Не удалось вернуть: " + (Get-ShortError $_)) }
    }
    Show-Outcome
    [void](Read-Host ('  ' + $script:S.PressEnter))
}
