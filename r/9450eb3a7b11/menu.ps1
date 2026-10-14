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
. (Join-Path $PSScriptRoot 'yandex-browser.ps1')

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

function Get-Loc($Pair) {
    $t = $Pair.$($script:Lang)
    if (-not $t) { $t = $Pair.en }
    return "$t"
}

function Get-PresetSettings($Preset) {
    $out = @()
    foreach ($id in @($Preset.items)) {
        $m = @($data.settings | Where-Object { $_.id -eq $id })
        if ($m.Count -gt 0) { $out += $m[0] }
    }
    return $out
}

function Get-ItemSettings($Item) {
    if ($Item.kind -eq 'preset') { return @(Get-PresetSettings $Item.preset) }
    if ($Item.kind -ne 'category' -and $Item.kind -ne 'group') { return @() }
    $ids = @($Item.categories)
    return @($data.settings | Where-Object { $ids -contains $_.category })
}

function Get-SectionItems($Section) {
    if ($Section.presets) {
        $out = @(); $n = 0
        foreach ($p in @($data.presets)) {
            if (-not $p) { continue }
            $n++
            $out += [pscustomobject]@{ addr = $n; kind = 'preset'; title = $p.title; desc = $p.desc; preset = $p; min_build = 0 }
        }
        return $out
    }
    return @($Section.items)
}

function Get-ProgramGroup($GroupId) {
    foreach ($g in @($data.programs)) { if ($g -and $g.id -eq $GroupId) { return $g } }
    return $null
}

function Get-ProgramItems($Group) {
    $out = @()
    foreach ($p in @($Group.items)) {
        if (-not $p) { continue }
        $name = @{ ru = "$($p.name.ru)"; en = "$($p.name.en)" }
        if ($p.url) { $out += @{ Kind = 'link'; Url = "$($p.url)"; Name = $name }; continue }
        $out += @{ Kind = 'winget'; Id = "$($p.id)"; Check = $p.check; Override = $null; Name = $name }
    }
    return $out
}

function Invoke-ProgramsScreen($GroupId) {
    $g = Get-ProgramGroup $GroupId
    if (-not $g) { return }
    $warn = @()
    if ($g.warn) { $warn = @($g.warn.$($script:Lang) | Where-Object { $_ }) }
    Invoke-DevToolsScreen (Get-ProgramItems $g) (Get-Loc $g.title) $warn
}

function Get-ItemGlyph($Item) {
    switch ($Item.kind) {
        'preset' { return 'preset' }
        'programs' { return 'devtools' }
        'module' { return "$($Item.module)" }
        default  { return (("$(@($Item.categories)[0])") -replace '^[^-]*-', '') }
    }
}

function Get-AppliedTail($Settings) {
    $all = @($Settings | Where-Object { $_ })
    if ($all.Count -eq 0) { return '' }
    $on = 0
    foreach ($s in $all) { if (Test-Applied $s) { $on++ } }
    return ($script:S.CountOf -f $on, $all.Count)
}

function Get-ModuleAddr($Module) {
    foreach ($sec in @($data.menu)) {
        foreach ($it in @(Get-SectionItems $sec)) {
            if ($it.kind -eq 'module' -and $it.module -eq $Module) { return ('{0}.{1}' -f $sec.addr, $it.addr) }
        }
    }
    return ''
}

function Invoke-Module($Id) {
    switch ($Id) {
        'terminal'    { Invoke-TerminalScreen }
        'ai-terminal' { Invoke-AiScreen }
        'devtools'    { Invoke-DevToolsScreen $script:DevToolItems $script:S.DevTitle $script:S.DevWarn }
        'ai-agents'   { Invoke-DevToolsScreen $script:AiAgentItems $script:S.AgentsTitle $script:S.AgentsWarn }
        'yandex-net'  { Invoke-YandexNetScreen }
        'certs'       { Invoke-CertsScreen }
        'yandex-browser' { Invoke-YandexBrowserScreen }
    }
}

function Open-Item($Item) {
    if ($build -lt [int]$Item.min_build) {
        Write-Host ''
        Write-Host ('  ' + $script:S.NotForWin) -ForegroundColor Yellow
        [void](Read-Host ('  ' + $script:S.PressEnter))
        return
    }
    switch ($Item.kind) {
        'module'   { Invoke-Module "$($Item.module)" }
        'programs' { Invoke-ProgramsScreen "$($Item.group)" }
        'category' { Invoke-CategoryScreen (Get-Loc $Item.title) (Get-ItemSettings $Item) "$(@($Item.categories)[0])" }
        'group'    { Invoke-PresetScreen (Get-Loc $Item.title) (Get-Loc $Item.desc) (Get-ItemSettings $Item) }
        'preset'   { Invoke-PresetScreen (Get-Loc $Item.title) (Get-Loc $Item.desc) (Get-ItemSettings $Item) }
    }
}

function Find-Section($Addr) {
    foreach ($sec in @($data.menu)) { if ([int]$sec.addr -eq $Addr) { return $sec } }
    return $null
}

function Find-Item($Section, $Addr) {
    foreach ($it in @(Get-SectionItems $Section)) { if ([int]$it.addr -eq $Addr) { return $it } }
    return $null
}

function Get-ItemInnerNames($Item) {
    $names = @()
    foreach ($s in @(Get-ItemSettings $Item)) { $names += @("$($s.title.ru)", "$($s.title.en)") }
    if ($Item.kind -eq 'module') {
        $list = @()
        if ($Item.module -eq 'devtools')  { $list = @($script:DevToolItems) }
        if ($Item.module -eq 'ai-agents') { $list = @($script:AiAgentItems) }
        foreach ($t in $list) { $names += @("$($t.Name.ru)", "$($t.Name.en)") }
    }
    if ($Item.kind -eq 'programs') {
        $g = Get-ProgramGroup "$($Item.group)"
        if ($g) { foreach ($t in @($g.items)) { $names += @("$($t.name.ru)", "$($t.name.en)") } }
    }
    return $names
}

function Get-SearchHits($Word) {
    $w = "$Word".Trim().ToLower()
    $hits = @()
    if ($w.Length -lt 2) { return $hits }
    foreach ($sec in @($data.menu)) {
        foreach ($it in @(Get-SectionItems $sec)) {
            $why = ''; $found = $false
            foreach ($n in @("$($it.title.ru)", "$($it.title.en)", "$($it.desc.ru)", "$($it.desc.en)")) {
                if ($n.ToLower().Contains($w)) { $found = $true }
            }
            if (-not $found) {
                foreach ($n in @(Get-ItemInnerNames $it)) {
                    if ($n.ToLower().Contains($w)) { $found = $true; $why = $n; break }
                }
            }
            if ($found) { $hits += @{ Section = $sec; Item = $it; Why = $why } }
        }
    }
    return $hits
}

function Invoke-Search($Word) {
    while ($true) {
        $hits = @(Get-SearchHits $Word)
        Clear-Host
        Write-Host ''
        Write-Section ($script:S.SearchTitle -f $Word)
        Write-Host ''
        if ($hits.Count -eq 0) {
            Write-Dim $script:S.SearchNone
            Write-Host ''
            [void](Read-Host ('  ' + $script:S.PressEnter))
            return
        }
        $n = 0
        foreach ($h in $hits) {
            $n++
            $where = ('{0}.{1} {2}' -f $h.Section.addr, $h.Item.addr, (Get-Loc $h.Item.title))
            Write-Entry ('[{0}]' -f $n) (Get-ItemGlyph $h.Item) $where '' '' ($build -ge [int]$h.Item.min_build)
            if ($h.Why) { Write-Dim ('        ' + ($script:S.SearchIn -f $h.Why)) }
        }
        Write-Host ''
        Write-Host ('  ' + $script:S.MenuBack)
        Write-Host ''
        $answer = (Read-Host ('  ' + $script:S.MenuAsk)).Trim()
        if ($answer -eq '0' -or $answer -eq '') { return }
        $index = 0
        if (-not [int]::TryParse($answer, [ref]$index)) { continue }
        if ($index -lt 1 -or $index -gt $hits.Count) { continue }
        Open-Item $hits[$index - 1].Item
    }
}

function Invoke-CommonInput($Answer) {
    if ($Answer.StartsWith('/')) { Invoke-Search $Answer.Substring(1); return $true }
    if ($Answer -match '^(\d+)\.(\d+)$') {
        $sec = Find-Section ([int]$Matches[1])
        if ($sec) {
            $it = Find-Item $sec ([int]$Matches[2])
            if ($it) { Open-Item $it }
        }
        return $true
    }
    return $false
}

function Show-Main {
    Clear-Host
    Write-Host ''
    Write-Plate @('AutoSettings.win', ($script:S.OsLine -f $product, $build))
    Write-Host ''
    foreach ($sec in @($data.menu)) {
        $settings = @()
        foreach ($it in @(Get-SectionItems $sec)) {
            if ($it.kind -eq 'category' -or $it.kind -eq 'group') { $settings += @(Get-ItemSettings $it) }
        }
        Write-Entry ('[{0}]' -f $sec.addr) 'section' (Get-Loc $sec.title) (Get-AppliedTail $settings) (Get-Loc $sec.desc) $true
    }
    Write-Host ''
    Write-Rule
    if ((-not (Test-ModernTerminal)) -and ($build -ge 18362)) {
        $addr = Get-ModuleAddr 'terminal'
        if ($addr) { Write-Dim ($script:S.WtHint -f $addr) }
    }
    Write-Dim $script:S.MenuHint
    Write-Host ''
    Write-Host ('  ' + $script:S.MenuLang + '    ' + $script:S.MenuExit)
    Write-Host ''
    Write-Dim $script:S.TermsNote
    Write-Dim $script:S.TermsUrl
    Write-Host ''
}

function Invoke-Section($Section) {
    $items = @(Get-SectionItems $Section)
    if ($items.Count -eq 1) { Open-Item $items[0]; return }
    while ($true) {
        Clear-Host
        Write-Host ''
        Write-Section ('{0}  {1}' -f $Section.addr, (Get-Loc $Section.title))
        Write-Host ''
        foreach ($it in $items) {
            $fits = ($build -ge [int]$it.min_build)
            $title = Get-Loc $it.title
            if (-not $fits) { $title = ($script:S.NeedBuild -f $title, $it.min_build) }
            $desc = ''
            if ($it.kind -ne 'preset') { $desc = Get-Loc $it.desc }
            Write-Entry ('[{0}]' -f $it.addr) (Get-ItemGlyph $it) $title (Get-AppliedTail (Get-ItemSettings $it)) $desc $fits
        }
        Write-Host ''
        Write-Rule
        if ($Section.id -eq 'privacy') { Write-Dim $script:S.EditionNote }
        Write-Dim $script:S.MenuHint
        Write-Host ''
        Write-Host ('  ' + $script:S.MenuBack)
        Write-Host ''
        $answer = (Read-Host ('  ' + $script:S.MenuAsk)).Trim()
        if ($answer -eq '0' -or $answer -eq '') { return }
        if (Invoke-CommonInput $answer) { continue }
        $index = 0
        if (-not [int]::TryParse($answer, [ref]$index)) { continue }
        $it = Find-Item $Section $index
        if ($it) { Open-Item $it }
    }
}

function Request-ModernTerminal {
    if (Test-WtInstalled) { return }
    if ($build -lt 18362) { return }
    Write-Host ''
    Write-Host ('  ' + $script:S.WtOffer)
    $ans = (Read-Host ('  ' + $script:S.WtAsk)).Trim().ToLower()
    if (-not (Test-Yes $ans)) { return }
    Start-Work
    Write-Live 'Windows Terminal'
    if (Install-WindowsTerminal) { Add-Outcome 'ok' $script:S.WtInstalled }
    else { Add-Outcome 'fail' $script:S.WtFail }
    Show-Outcome
    [void](Read-Host ('  ' + $script:S.PressEnter))
}

Choose-Language
$Host.UI.RawUI.WindowTitle = 'autosettings.win'

while ($true) {
    Show-Main
    $answer = (Read-Host ('  ' + $script:S.MenuAsk)).Trim()
    if ($answer -eq '0') { break }
    if ((Get-Key $answer) -eq 'l') {
        if ($script:Lang -eq 'ru') { Set-Language 'en' } else { Set-Language 'ru' }
        continue
    }
    if (Invoke-CommonInput $answer) { continue }
    $index = 0
    if (-not [int]::TryParse($answer, [ref]$index)) { continue }
    $sec = Find-Section $index
    if ($sec) { Invoke-Section $sec }
}
