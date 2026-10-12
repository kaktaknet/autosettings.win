param([string]$ManifestPin)

$script:ManifestPin = $ManifestPin

. (Join-Path $PSScriptRoot 'lib.ps1')
. (Join-Path $PSScriptRoot 'strings.ps1')
. (Join-Path $PSScriptRoot 'ui.ps1')
. (Join-Path $PSScriptRoot 'terminal.ps1')
. (Join-Path $PSScriptRoot 'aiterm.ps1')
. (Join-Path $PSScriptRoot 'wsl.ps1')
. (Join-Path $PSScriptRoot 'devtools.ps1')
. (Join-Path $PSScriptRoot 'certs.ps1')
. (Join-Path $PSScriptRoot 'yandex-net.ps1')

$data = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'settings.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json

$windows = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$build   = [int]$windows.CurrentBuildNumber
$product = [string]$windows.ProductName
if ($build -ge 22000) { $product = $product -replace 'Windows 10', 'Windows 11' }

$script:Ui = Get-UiCaps $build

function Get-DefaultLang {
    $c = ''
    try { $c = (Get-UICulture).Name } catch {}
    if (-not $c) { $c = "$PSUICulture" }
    if ($c -match '^(ru|uk|be|kk|ky|uz|tg|hy|az|tk|ka|tt)(-|$)') { return 'ru' }
    return 'en'
}

$script:Lang = Get-DefaultLang
$script:S = $AllStrings[$script:Lang]

function Set-Language($lang) {
    $script:Lang = $lang
    $script:S = $AllStrings[$lang]
}

function Choose-Language {
    $default = Get-DefaultLang
    $defName = if ($default -eq 'ru') { $AllStrings.ru.LangRuName } else { $AllStrings.en.LangEnName }
    Clear-Host
    Write-Host ''
    Write-Host '  autosettings.win' -ForegroundColor Cyan
    Write-Host ''
    Write-Host ('  ' + $AllStrings.ru.ChooseLang + ' / ' + $AllStrings.en.ChooseLang)
    Write-Host ('  ' + $AllStrings.ru.LangRu)
    Write-Host ('  ' + $AllStrings.en.LangEn)
    Write-Host ('  ' + ($AllStrings.en.LangEnter -f $defName)) -ForegroundColor DarkGray
    Write-Host ''
    $pick = (Read-Host ('  ' + $AllStrings.ru.LangAsk + ' / ' + $AllStrings.en.LangAsk)).Trim()
    switch ($pick) {
        '1' { Set-Language 'ru' }
        '2' { Set-Language 'en' }
        default { Set-Language $default }
    }
}

function Test-CategoryFits($Category) {
    return ($build -ge [int]$Category.min_build)
}

function Get-CatTitle($Category) {
    $t = $Category.title.$($script:Lang)
    if (-not $t) { $t = $Category.title.en }
    return $t
}

function Get-PresetTitle($Preset) {
    $t = $Preset.title.$($script:Lang)
    if (-not $t) { $t = $Preset.title.en }
    return $t
}

function Get-PresetDesc($Preset) {
    $d = $Preset.desc.$($script:Lang)
    if (-not $d) { $d = $Preset.desc.en }
    return $d
}

function Get-SectionOf($Category) {
    $s = "$($Category.section)"
    if (-not $s) { $s = 'privacy' }
    return $s
}

function Get-SectionTitle($Section) {
    switch ($Section) {
        'presets' { return $script:S.SectionPresets }
        'privacy' { return $script:S.SectionPrivacy }
        'system'  { return $script:S.SectionSystem }
        'dev'     { return $script:S.SectionDev }
        default   { return '' }
    }
}

function Build-MenuEntries {
    $entries = @()
    foreach ($p in @($data.presets)) {
        if ($p) { $entries += @{ Kind = 'preset'; Ref = $p; Glyph = 'preset'; Section = 'presets' } }
    }
    $modules = @(
        @{ Ref = 'yandex-net';  Glyph = 'yandex-net';  Section = 'system'; MinBuild = 22000 },
        @{ Ref = 'certs';       Glyph = 'certs';       Section = 'system'; MinBuild = 10240 },
        @{ Ref = 'terminal';    Glyph = 'terminal';    Section = 'dev';    MinBuild = 10240 },
        @{ Ref = 'ai-terminal'; Glyph = 'ai-terminal'; Section = 'dev';    MinBuild = 10240 },
        @{ Ref = 'devtools';    Glyph = 'devtools';    Section = 'dev';    MinBuild = 10240 }
    )
    $order = @('privacy', 'system')
    $seen = @{}
    foreach ($o in $order) { $seen[$o] = $true }
    foreach ($cat in @($data.categories)) {
        $sec = Get-SectionOf $cat
        if (-not $seen.ContainsKey($sec)) { $order += $sec; $seen[$sec] = $true }
    }
    if (-not $seen.ContainsKey('dev')) { $order += 'dev'; $seen['dev'] = $true }
    foreach ($sec in $order) {
        foreach ($cat in @($data.categories)) {
            if ((Get-SectionOf $cat) -eq $sec) {
                $key = ($cat.id -replace '^[^-]*-', '')
                $entries += @{ Kind = 'category'; Ref = $cat; Glyph = $key; Section = $sec }
            }
        }
        foreach ($m in $modules) {
            if ($m.Section -eq $sec) {
                $entries += @{ Kind = 'module'; Ref = $m.Ref; Glyph = $m.Glyph; Section = $sec; MinBuild = $m.MinBuild }
            }
        }
    }
    return $entries
}

function Show-Menu {
    Clear-Host
    Write-Host ''
    Write-Plate @('AutoSettings.win', ($script:S.OsLine -f $product, $build))
    Write-Host ''
    $script:MenuEntries = @(Build-MenuEntries)
    $curSec = ''
    $n = 0
    foreach ($e in $script:MenuEntries) {
        if ($e.Section -ne $curSec) {
            if ($n -gt 0) { Write-Host '' }
            Write-Section (Get-SectionTitle $e.Section)
            $curSec = $e.Section
        }
        $n++
        switch ($e.Kind) {
            'preset' {
                Write-Item $n $e.Glyph (Get-PresetTitle $e.Ref) $true
            }
            'category' {
                $cat = $e.Ref
                if (Test-CategoryFits $cat) {
                    Write-Item $n $e.Glyph (Get-CatTitle $cat) $true
                }
                else {
                    Write-Item $n $e.Glyph ($script:S.NeedBuild -f (Get-CatTitle $cat), $cat.min_build) $false
                }
            }
            'module' {
                $label = switch ($e.Ref) {
                    'terminal'    { $script:S.TermCat }
                    'ai-terminal' { $script:S.AiCat }
                    'devtools'    { $script:S.DevCat }
                    'yandex-net'  { $script:S.YandexNetCat }
                    'certs'       { $script:S.CertCat }
                }
                if ($build -ge [int]$e.MinBuild) {
                    Write-Item $n $e.Glyph $label $true
                }
                else {
                    Write-Item $n $e.Glyph ($script:S.NeedBuild -f $label, $e.MinBuild) $false
                }
            }
        }
    }
    Write-Host ''
    Write-Rule
    Write-Dim $script:S.EditionNote
    Write-Host ''
    Write-Host ('  ' + $script:S.MenuLang)
    Write-Host ('  ' + $script:S.MenuExit)
    Write-Host ''
}

function Request-ModernTerminal {
    if (Test-ModernTerminal) { return }
    if ($build -lt 18362) { return }
    Write-Host ''
    Write-Host ('  ' + $script:S.WtOffer)
    $ans = (Read-Host ('  ' + $script:S.WtAsk)).Trim().ToLower()
    if (-not (Test-Yes $ans)) { return }
    Write-Host ('  ' + $script:S.WtInstalling) -ForegroundColor DarkGray
    if (Install-WindowsTerminal) { Write-Host ('  ' + $script:S.WtInstalled) -ForegroundColor Green }
    else { Write-Host ('  ' + $script:S.WtFail) -ForegroundColor Yellow }
    [void](Read-Host ('  ' + $script:S.PressEnter))
}

Choose-Language
Request-ModernTerminal
$Host.UI.RawUI.WindowTitle = 'autosettings.win'

while ($true) {
    Show-Menu
    $answer = (Read-Host ('  ' + $script:S.MenuAsk)).Trim()
    if ($answer -eq '0') { break }
    if ($answer -eq 'l' -or $answer -eq 'L' -or $answer -eq 'я' -or $answer -eq 'Я') {
        if ($script:Lang -eq 'ru') { Set-Language 'en' } else { Set-Language 'ru' }
        continue
    }

    $index = 0
    if (-not [int]::TryParse($answer, [ref]$index)) { continue }
    $entries = @($script:MenuEntries)
    if ($index -lt 1 -or $index -gt $entries.Count) { continue }
    $e = $entries[$index - 1]

    switch ($e.Kind) {
        'module' {
            if ($build -lt [int]$e.MinBuild) {
                Write-Host ''
                Write-Host ('  ' + $script:S.NotForWin) -ForegroundColor Yellow
                [void](Read-Host ('  ' + $script:S.PressEnter))
            }
            else {
                switch ($e.Ref) {
                    'terminal'    { Invoke-TerminalScreen }
                    'ai-terminal' { Invoke-AiScreen }
                    'devtools'    { Invoke-DevToolsScreen }
                    'yandex-net'  { Invoke-YandexNetScreen }
                    'certs'       { Invoke-CertsScreen }
                }
            }
        }
        'preset' {
            $presetSettings = @()
            foreach ($id in @($e.Ref.items)) {
                $m = @($data.settings | Where-Object { $_.id -eq $id })
                if ($m.Count -gt 0) { $presetSettings += $m[0] }
            }
            Invoke-PresetScreen (Get-PresetTitle $e.Ref) (Get-PresetDesc $e.Ref) $presetSettings
        }
        'category' {
            $cat = $e.Ref
            if (-not (Test-CategoryFits $cat)) {
                Write-Host ''
                Write-Host ('  ' + $script:S.NotForWin) -ForegroundColor Yellow
                [void](Read-Host ('  ' + $script:S.PressEnter))
            }
            else {
                $catSettings = @($data.settings | Where-Object { $_.category -eq $cat.id })
                Invoke-CategoryScreen (Get-CatTitle $cat) $catSettings $cat.id
            }
        }
    }
}
