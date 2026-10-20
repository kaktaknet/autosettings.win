param([string]$ManifestPin)

$script:ManifestPin = $ManifestPin

. (Join-Path $PSScriptRoot 'lib.ps1')
. (Join-Path $PSScriptRoot 'strings.ps1')
. (Join-Path $PSScriptRoot 'ui.ps1')
. (Join-Path $PSScriptRoot 'terminal.ps1')
. (Join-Path $PSScriptRoot 'aiterm.ps1')
. (Join-Path $PSScriptRoot 'wsl.ps1')
. (Join-Path $PSScriptRoot 'restore-point.ps1')
. (Join-Path $PSScriptRoot 'repair.ps1')
. (Join-Path $PSScriptRoot 'components.ps1')
. (Join-Path $PSScriptRoot 'classic-panels.ps1')
. (Join-Path $PSScriptRoot 'devtools.ps1')
. (Join-Path $PSScriptRoot 'programs-transfer.ps1')
. (Join-Path $PSScriptRoot 'certs.ps1')
. (Join-Path $PSScriptRoot 'yandex-net.ps1')
. (Join-Path $PSScriptRoot 'browser-family.ps1')
. (Join-Path $PSScriptRoot 'yandex-browser.ps1')
. (Join-Path $PSScriptRoot 'chromium-gost.ps1')
. (Join-Path $PSScriptRoot 'firefox-addons.ps1')

$data = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'settings.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$script:WingetArch = $data.winget
$script:WingetUser = $data.winget_user

$windows = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$build   = [int]$windows.CurrentBuildNumber
$ubr     = [int]$windows.UBR
$edition = [string]$windows.EditionID
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

function Choose-Arch {
    while ($true) {
        Clear-Host
        Write-Host ''
        Write-Host ('  ' + $script:S.ArchTitle)
        Write-Host ''
        Write-Host ('  ' + $script:S.ArchPick1)
        Write-Host ('  ' + $script:S.ArchPick2)
        Write-Host ('  ' + $script:S.ArchPick3)
        Write-Host ''
        Write-Dim $script:S.ArchWhere
        Write-Host ''
        switch ((Read-Host ('  ' + $script:S.ArchAsk)).Trim()) {
            '1' { return 'x64' }
            '2' { return 'arm64' }
            '3' { return 'x86' }
        }
    }
}

function Show-Preflight {
    $issues = @(Get-PreflightIssues)
    if ($issues.Count -eq 0) { return $true }
    Clear-Host
    Write-Host ''
    Write-Host ('  ' + $script:S.PreTitle)
    foreach ($i in $issues) {
        Write-Host ''
        switch ($i.Kind) {
            'reboot'  { Write-Host ('  ' + $script:S.PreReboot) }
            'space'   { Write-Host ('  ' + ($script:S.PreSpace -f $i.Value)) }
            'account' { Write-Host ('  ' + ($script:S.PreAccount -f $i.Value[0], $i.Value[1])) }
        }
    }
    Write-Host ''
    return ((Read-Host ('  ' + $script:S.PreAsk)).Trim() -ne '0')
}

function Get-ArchLabel {
    switch ($script:Arch) {
        'arm64' { return $script:S.ArchArm64 }
        'x86' { return $script:S.ArchX86 }
    }
    return $script:S.ArchX64
}

function Get-Loc($Pair) {
    $t = $Pair.$($script:Lang)
    if (-not $t) { $t = $Pair.en }
    return "$t"
}

function Test-SettingFits($Setting) {
    if ($build -lt [int]$Setting.min_build) { return $false }
    if ($Setting.max_build -and $build -gt [int]$Setting.max_build) { return $false }
    if ($Setting.min_ubr -and $build -eq [int]$Setting.min_build -and $ubr -lt [int]$Setting.min_ubr) { return $false }
    if ($Setting.editions) {
        $hit = $false
        foreach ($e in @($Setting.editions)) { if ($edition -like "$e*") { $hit = $true } }
        if (-not $hit) { return $false }
    }
    return $true
}

function Get-PresetSettings($Preset) {
    $out = @()
    foreach ($id in @($Preset.items)) {
        $m = @($data.settings | Where-Object { $_.id -eq $id -and (Test-SettingFits $_) })
        if ($m.Count -gt 0) { $out += $m[0] }
    }
    return $out
}

function Get-ItemSettings($Item) {
    if ($Item.kind -eq 'preset') { return @(Get-PresetSettings $Item.preset) }
    if ($Item.kind -ne 'category' -and $Item.kind -ne 'group') { return @() }
    $fit = @($data.settings | Where-Object { Test-SettingFits $_ })
    $out = @()
    foreach ($id in @($Item.categories)) {
        $own = @($fit | Where-Object { $_.category -eq $id })
        $out += @($own | Where-Object { -not $_.optional })
        $out += @($own | Where-Object { $_.optional })
    }
    return $out
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
        if ($p.spacer) { $out += @{ Kind = 'blank' }; continue }
        $name = @{ ru = "$($p.name.ru)"; en = "$($p.name.en)" }
        if ($p.url) { $out += @{ Kind = 'link'; Url = "$($p.url)"; Name = $name; Arch = $p.arch }; continue }
        if ($p.module) { $out += @{ Kind = 'action'; Module = "$($p.module)"; Action = "$($p.action)"; Name = $name; Arch = $p.arch }; continue }
        $out += @{ Kind = 'winget'; Id = "$($p.id)"; Check = $p.check; Override = $null; Name = $name; Arch = $p.arch }
    }
    return $out
}

function Test-ItemOnThisPc($Item) {
    if ($Item.arch -and -not (@($Item.arch) -contains $script:Arch)) { return $false }
    if ($Item.kind -eq 'programs') {
        $g = Get-ProgramGroup "$($Item.group)"
        if (-not $g) { return $false }
        if ($g.arch -and -not (@($g.arch) -contains $script:Arch)) { return $false }
        return (@(Select-FittingItems (Get-ProgramItems $g) | Where-Object { $_.Kind -ne 'blank' }).Count -gt 0)
    }
    if ($Item.kind -eq 'module' -and $Item.module -eq 'devtools') { return (@(Select-FittingItems $script:DevToolItems).Count -gt 0) }
    if ($Item.kind -eq 'module' -and $Item.module -eq 'ai-agents') { return (@(Select-FittingItems $script:AiAgentItems).Count -gt 0) }
    return $true
}

function Get-VisibleItems($Section) {
    return @(Get-SectionItems $Section | Where-Object { Test-ItemOnThisPc $_ })
}

function Show-NotHere {
    Write-Host ''
    Write-Host ('  ' + ($script:S.NotHere -f (Get-ArchLabel))) -ForegroundColor Yellow
    [void](Read-Host ('  ' + $script:S.PressEnter))
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
        'dns-providers' { Invoke-DnsProviderScreen }
        'certs'       { Invoke-CertsScreen }
        'restore-point' { Invoke-RestorePointScreen }
        'repair'      { Invoke-RepairScreen }
        'components'  { Invoke-ComponentsScreen }
        'classic-panels' { Invoke-ClassicPanelsScreen }
        'programs-transfer' { Invoke-ProgramsTransferScreen }
    }
}

function Invoke-ProgramModuleAction($Module, $Action) {
    switch ("$Module") {
        'yandex-browser' { Invoke-YandexBrowserAction "$Action" }
        'chromium-gost'  { Invoke-ChromiumGostAction "$Action" }
        'firefox-addons' { Invoke-FirefoxAddonsAction "$Action" }
        'google-chrome'  { Invoke-GoogleChromeAction "$Action" }
    }
}

function Open-Item($Item) {
    if (-not (Test-ItemOnThisPc $Item)) { Show-NotHere; return }
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
        'preset'   {
            $mods = @(@($Item.preset.modules) | Where-Object {
                $null -ne $_ -and (-not $_.arch -or @($_.arch) -contains $script:Arch) -and $build -ge [int]$_.min_build })
            Invoke-PresetScreen (Get-Loc $Item.title) (Get-Loc $Item.desc) (Get-ItemSettings $Item) $mods
        }
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
    foreach ($s in @(Get-ItemSettings $Item)) { $names += @{ N = "$($s.title.ru)"; Fits = $true }, @{ N = "$($s.title.en)"; Fits = $true } }
    $list = @()
    if ($Item.kind -eq 'module' -and $Item.module -eq 'devtools')  { $list = @($script:DevToolItems) }
    if ($Item.kind -eq 'module' -and $Item.module -eq 'ai-agents') { $list = @($script:AiAgentItems) }
    if ($Item.kind -eq 'programs') {
        $g = Get-ProgramGroup "$($Item.group)"
        if ($g) { $list = @(Get-ProgramItems $g) }
    }
    foreach ($t in $list) {
        if (-not $t -or $t.Kind -eq 'blank') { continue }
        $fits = [bool](Test-DevItemFits $t)
        $names += @{ N = "$($t.Name.ru)"; Fits = $fits }, @{ N = "$($t.Name.en)"; Fits = $fits }
    }
    return $names
}

function Get-SearchHits($Word) {
    $w = "$Word".Trim().ToLower()
    $hits = @()
    if ($w.Length -lt 2) { return $hits }
    foreach ($sec in @($data.menu)) {
        foreach ($it in @(Get-SectionItems $sec)) {
            $why = ''; $found = $false; $fits = [bool](Test-ItemOnThisPc $it)
            foreach ($n in @("$($it.title.ru)", "$($it.title.en)", "$($it.desc.ru)", "$($it.desc.en)")) {
                if ($n.ToLower().Contains($w)) { $found = $true }
            }
            if (-not $found) {
                foreach ($n in @(Get-ItemInnerNames $it)) {
                    if ($n.N.ToLower().Contains($w)) { $found = $true; $why = $n.N; if (-not $n.Fits) { $fits = $false }; break }
                }
            }
            if ($found) { $hits += @{ Section = $sec; Item = $it; Why = $why; Fits = $fits } }
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
            Write-Entry ('[{0}]' -f $n) (Get-ItemGlyph $h.Item) $where '' '' ($h.Fits -and ($build -ge [int]$h.Item.min_build))
            if (-not $h.Fits) {
                $what = if ($h.Why) { $h.Why } else { Get-Loc $h.Item.title }
                Write-Dim ('        ' + ($script:S.SearchNotHere -f (Get-ArchLabel), $what))
            }
            elseif ($h.Why) { Write-Dim ('        ' + ($script:S.SearchIn -f $h.Why)) }
        }
        Write-Host ''
        Write-Host ('  ' + $script:S.MenuBack)
        Write-Host ''
        $answer = (Read-Host ('  ' + $script:S.MenuAsk)).Trim()
        if ($answer -eq '0' -or $answer -eq '') { return }
        $index = 0
        if (-not [int]::TryParse($answer, [ref]$index)) { continue }
        if ($index -lt 1 -or $index -gt $hits.Count) { continue }
        if (-not $hits[$index - 1].Fits) { Show-NotHere; continue }
        Open-Item $hits[$index - 1].Item
    }
}

function Invoke-CommonInput($Answer) {
    if ($Answer.StartsWith('/')) { Invoke-Search $Answer.Substring(1); return $true }
    if ((Get-Key $Answer) -eq 'j') { Invoke-ChangedScreen; return $true }
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

function Invoke-ChangedScreen {
    while ($true) {
        $ids = @(Get-ChangedIds)
        $list = @()
        foreach ($cat in @($data.categories)) {
            $list += @($data.settings | Where-Object { $_.category -eq $cat.id -and ($ids -contains $_.id) -and (Test-SettingFits $_) -and (Test-Applied $_) })
        }
        Clear-Host
        Write-Host ''
        Write-Host ('  ' + $script:S.ChangedTitle) -ForegroundColor Cyan
        Write-Host ''
        if ($list.Count -eq 0) {
            Write-Host ('  ' + $script:S.ChangedEmpty)
            Write-Host ''
            [void](Read-Host ('  ' + $script:S.PressEnter))
            return
        }
        $n = 0; $cur = ''
        foreach ($s in $list) {
            if ($s.category -ne $cur) {
                $cur = $s.category
                $cat = @($data.categories | Where-Object { $_.id -eq $cur })[0]
                Write-Host ''
                Write-Host ('  ' + (Get-Loc $cat.title)) -ForegroundColor Cyan
            }
            $n++
            Write-Host ('  [{0}] {1}' -f $n, (Get-Title $s))
        }
        Write-Host ''
        Write-Dim $script:S.ChangedModules
        Write-Host ('  ' + $script:S.ChangedActions)
        Write-Host ''
        $answer = (Read-Host ('  ' + $script:S.Choice)).Trim()
        if ($answer -eq '0' -or $answer -eq '') { return }
        if ((Get-Key $answer) -eq 'r') { Invoke-PresetRevert $list; Pause-Return; continue }
        $picked = @(); $bad = $false
        foreach ($tok in @($answer -split '[,\s]+' | Where-Object { $_ -ne '' })) {
            $num = 0
            if ([int]::TryParse($tok, [ref]$num) -and $num -ge 1 -and $num -le $list.Count) { $picked += $list[$num - 1] }
            else { $bad = $true }
        }
        if ($bad -or $picked.Count -eq 0) {
            Write-Host ''
            Write-Host ('  ' + $script:S.ChangedBad) -ForegroundColor Yellow
            Pause-Return
            continue
        }
        Invoke-PresetRevert $picked
        Pause-Return
    }
}

function Show-Main {
    Clear-Host
    Write-Host ''
    Write-Plate @('AutoSettings.win', ($script:S.OsLine -f $product, $build, (Get-ArchLabel)))
    Write-Host ''
    foreach ($sec in @($data.menu)) {
        if (@(Get-VisibleItems $sec).Count -eq 0) { continue }
        $settings = @()
        foreach ($it in @(Get-VisibleItems $sec)) {
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
    Write-Host ('  ' + $script:S.MenuChanged + '    ' + $script:S.MenuLang + '    ' + $script:S.MenuExit)
    Write-Host ''
    Write-Dim $script:S.TermsNote
    Write-Dim $script:S.TermsUrl
    Write-Host ''
}

function Invoke-Section($Section) {
    $items = @(Get-VisibleItems $Section)
    if ($items.Count -eq 0) { Show-NotHere; return }
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
$script:Arch = (Get-ArchProfile).Arch
if (-not $script:Arch) { $script:Arch = Choose-Arch }
if (-not (Show-Preflight)) { return }
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
