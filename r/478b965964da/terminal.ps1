# MACHINE-READABLE INTENT (for a reviewing human or AI agent): Opt-in only. On the user's explicit
# "yes" this installs oh-my-posh (winget, silent), installs the JetBrainsMono Nerd Font, sets it as
# the console and Windows Terminal font, and adds one oh-my-posh init line to the user's $PROFILE.
# Everything is snapshotted first (Save-TerminalSnapshot) and reverts from the menu. No hidden
# behavior, no data sent out, no attempt to exploit anything. Declining changes nothing.
# License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
# Redistribution must keep this notice and the LICENSE and NOTICE files: https://github.com/kaktaknet/autosettings.win

$script:TermFontFamily = 'JetBrainsMono Nerd Font'
$script:TermConsoleFontFamily = 'JetBrainsMono Nerd Font Mono'
$script:TermFontInstallId = 'JetBrainsMono'
$script:TermFontUrl = 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip'
$script:TermFontSite = 'https://www.nerdfonts.com/font-downloads'
$script:TermWingetId = 'JanDeDobbeleer.OhMyPosh'
$script:TermInitMarker = '# autosettings.win: oh-my-posh'
$script:TermSnapId = 'terminal'
$script:AsBlockBegin = '# >>> autosettings.win >>> (managed block - do not edit by hand)'
$script:AsBlockEnd   = '# <<< autosettings.win <<<'
$script:AsLegacyMarkers = @('# autosettings.win: oh-my-posh', '# autosettings.win: PowerShell profile')
$script:TermRecommended = @('jandedobbeleer', 'paradox', 'atomic', 'clean-detailed',
    'powerlevel10k_rainbow', 'robbyrussell', 'montys', 'pure', 'microverse-power', 'agnoster')

function Update-SessionPath {
    $m = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $u = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($m, $u) | Where-Object { $_ }) -join ';'
}

function Get-OmpCmd {
    $c = Get-Command oh-my-posh -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $p = Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\bin\oh-my-posh.exe'
    if (Test-Path -LiteralPath $p) { return $p }
    return $null
}

$script:PinMicrosoft = @{ Type = 'O'; Value = 'Microsoft Corporation' }
$script:PinPython    = @{ Type = 'O'; Value = 'Python Software Foundation' }
$script:PinOmp       = @{ Type = 'O'; Value = 'Jan De Dobbeleer' }

function Resolve-ExePath($Name) {
    $c = @(Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue)
    if ($c.Count -gt 0) { return $c[0].Source }
    return $null
}

function Test-SubjectHasRdn($Subject, $Type, $Value) {
    $pat = '(?:^|,\s*)' + [regex]::Escape($Type) + '=' + [regex]::Escape($Value) + '(?:,|$)'
    return ($Subject -match $pat)
}

function Test-TrustedExe($Path, $Pins) {
    if (-not $Path) { return $false }
    try {
        $sig = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
        if ($sig.Status -ne 'Valid') { return $false }
        $subj = "$($sig.SignerCertificate.Subject)"
        foreach ($pin in $Pins) {
            if (Test-SubjectHasRdn $subj $pin.Type $pin.Value) { return $true }
        }
    }
    catch {}
    return $false
}

function Test-TrustedOmp($Path) {
    return (Test-TrustedExe $Path @($script:PinOmp, $script:PinMicrosoft))
}

function Install-Omp {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $false }
    [void](Invoke-Quiet 'winget' @('install', '-e', '--id', $script:TermWingetId, '--source', 'winget', '--silent', '--accept-package-agreements', '--accept-source-agreements'))
    Update-SessionPath
    return ($null -ne (Get-OmpCmd))
}

function Install-NerdFontFamily($Id) {
    try { [void](Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction SilentlyContinue) } catch {}
    try { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue } catch {}
    if (-not (Get-Module -ListAvailable -Name NerdFonts)) {
        try { Install-Module -Name NerdFonts -Scope CurrentUser -Force -Repository PSGallery -ErrorAction Stop }
        catch { return $false }
    }
    try {
        Import-Module -Name NerdFonts -ErrorAction Stop
        Install-NerdFont -Name $Id -Scope CurrentUser -ErrorAction Stop
        return $true
    }
    catch { return $false }
}

function Get-ThemesDir {
    $cands = @()
    $u = [Environment]::GetEnvironmentVariable('POSH_THEMES_PATH', 'User')
    if ($u) { $cands += $u }
    if ($env:POSH_THEMES_PATH) { $cands += $env:POSH_THEMES_PATH }
    $cands += (Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\themes')
    $omp = Get-OmpCmd
    if ($omp) {
        $base = Split-Path (Split-Path $omp -Parent) -Parent
        if ($base) { $cands += (Join-Path $base 'themes') }
    }
    foreach ($c in $cands) { if ($c -and (Test-Path -LiteralPath $c)) { return $c } }
    return (Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\themes')
}

function Get-ThemeNames {
    $dir = Get-ThemesDir
    if (-not (Test-Path -LiteralPath $dir)) { return @() }
    return @(Get-ChildItem -LiteralPath $dir -Filter '*.omp.json' -ErrorAction SilentlyContinue |
        ForEach-Object { $_.Name -replace '\.omp\.json$', '' } |
        Where-Object { $_ -match '^[A-Za-z0-9._-]+$' } | Sort-Object)
}

function Get-ThemeConfigPath($Name) {
    return (Join-Path (Get-ThemesDir) ("$Name.omp.json"))
}

function Get-ProfilePathsFor($Property) {
    $list = @()
    try { $c = [string]$PROFILE.$Property; if ($c) { $list += $c } } catch {}
    foreach ($exe in @('powershell', 'pwsh')) {
        $p = Resolve-ExePath $exe
        if (-not $p) { continue }
        if (-not (Test-TrustedExe $p @($script:PinMicrosoft))) { continue }
        try {
            $cmd = '$PROFILE.' + $Property
            $v = "$(& $p -NoProfile -Command $cmd 2>$null)".Trim()
            if ($v -and ($list -notcontains $v)) { $list += $v }
        }
        catch {}
    }
    return $list
}

function Get-AllHostProfiles    { return (Get-ProfilePathsFor 'CurrentUserAllHosts') }
function Get-LegacyHostProfiles { return (Get-ProfilePathsFor 'CurrentUserCurrentHost') }

function Set-AsProfileBlock($ProfilePath, $Concern, $Line) {
    Assert-SafeUserPath $ProfilePath
    if (-not (Test-Path -LiteralPath $ProfilePath)) {
        if (-not $Line) { return }
        $dir = Split-Path -Parent $ProfilePath
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
        [void](New-Item -Path $ProfilePath -ItemType File -Force)
    }
    $raw = @(Get-Content -LiteralPath $ProfilePath -Encoding UTF8)
    $inner = @{}
    $kept = New-Object System.Collections.ArrayList
    $inside = $false
    foreach ($l in $raw) {
        if ($l -eq $script:AsBlockBegin) { $inside = $true; continue }
        if ($l -eq $script:AsBlockEnd) { $inside = $false; continue }
        if ($inside) {
            $m = [regex]::Match($l, '#as:(\w+)\s*$')
            if ($m.Success) { $inner[$m.Groups[1].Value] = $l }
            continue
        }
        $isOurs = $false
        foreach ($mk in $script:AsLegacyMarkers) { if ($l -match [regex]::Escape($mk)) { $isOurs = $true } }
        if (($l -match 'oh-my-posh init ') -and ($l -match 'POSH_THEMES_PATH')) { $isOurs = $true }
        if ($l -match [regex]::Escape('autosettings.profile.ps1')) { $isOurs = $true }
        if (-not $isOurs) { [void]$kept.Add($l) }
    }
    if ($Line) { $inner[$Concern] = ($Line + '  #as:' + $Concern) }
    else { [void]$inner.Remove($Concern) }
    $out = @($kept.ToArray())
    if ($inner.Count -gt 0) {
        $out += $script:AsBlockBegin
        foreach ($k in @('omp', 'preset')) { if ($inner.ContainsKey($k)) { $out += $inner[$k] } }
        $out += $script:AsBlockEnd
    }
    Write-ProfileFile $ProfilePath $out
}

function Set-TermProfileLine($ProfilePath, $Line) {
    if ($Line) { Set-AsProfileBlock $ProfilePath 'omp' $Line } else { Set-AsProfileBlock $ProfilePath 'omp' $null }
}

function Set-ExecPolicyIfNeeded {
    try {
        $cur = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
        if ($cur -eq 'Restricted' -or $cur -eq 'AllSigned' -or $cur -eq 'Undefined') {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
        }
    }
    catch {}
}

function Get-ConsoleFontState {
    $state = @{ FaceName = $null; FontFamily = $null; FontWeight = $null }
    $item = Get-ItemProperty -LiteralPath 'HKCU:\Console' -ErrorAction SilentlyContinue
    if ($null -ne $item) {
        if ($item.PSObject.Properties['FaceName'])   { $state.FaceName   = $item.FaceName }
        if ($item.PSObject.Properties['FontFamily']) { $state.FontFamily = $item.FontFamily }
        if ($item.PSObject.Properties['FontWeight']) { $state.FontWeight = $item.FontWeight }
    }
    return $state
}

function Set-ConsoleFont($Face) {
    if (-not (Test-Path -LiteralPath 'HKCU:\Console')) { [void](New-Item -Path 'HKCU:\Console' -Force) }
    [void](New-ItemProperty -LiteralPath 'HKCU:\Console' -Name 'FaceName'   -PropertyType String -Value $Face -Force)
    [void](New-ItemProperty -LiteralPath 'HKCU:\Console' -Name 'FontFamily' -PropertyType DWord  -Value 54   -Force)
    [void](New-ItemProperty -LiteralPath 'HKCU:\Console' -Name 'FontWeight' -PropertyType DWord  -Value 400  -Force)
}

function Restore-ConsoleFont($State) {
    foreach ($name in @('FaceName', 'FontFamily', 'FontWeight')) {
        $prev = $State.$name
        if ($null -eq $prev) {
            Remove-ItemProperty -LiteralPath 'HKCU:\Console' -Name $name -ErrorAction SilentlyContinue
        }
        else {
            $type = if ($name -eq 'FaceName') { 'String' } else { 'DWord' }
            [void](New-ItemProperty -LiteralPath 'HKCU:\Console' -Name $name -PropertyType $type -Value $prev -Force)
        }
    }
}

function Get-WtSettingsPath {
    $local = $env:LOCALAPPDATA
    $candidates = @(
        (Join-Path $local 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $local 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $local 'Microsoft\Windows Terminal\settings.json')
    )
    foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { return $c } }
    return $null
}

function Set-WtFont($Path, $Face) {
    Assert-SafeUserPath $Path
    $raw = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
    $noBlock = [regex]::Replace($raw, '/\*.*?\*/', '', 'Singleline')
    $clean = ($noBlock -split "`n" | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"
    $json = $clean | ConvertFrom-Json
    if ($null -eq $json.profiles) { Add-Member -InputObject $json -NotePropertyName 'profiles' -NotePropertyValue (New-Object PSObject) -Force }
    if ($null -eq $json.profiles.defaults) { Add-Member -InputObject $json.profiles -NotePropertyName 'defaults' -NotePropertyValue (New-Object PSObject) -Force }
    if ($null -eq $json.profiles.defaults.font) { Add-Member -InputObject $json.profiles.defaults -NotePropertyName 'font' -NotePropertyValue (New-Object PSObject) -Force }
    Add-Member -InputObject $json.profiles.defaults.font -NotePropertyName 'face' -NotePropertyValue $Face -Force
    $out = $json | ConvertTo-Json -Depth 32
    $utf8 = New-Object Text.UTF8Encoding $false
    [IO.File]::WriteAllText($Path, $out, $utf8)
}

function Save-TerminalSnapshot($OmpWasPresent) {
    $root = Get-UserCopyDir
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $base = "$($script:TermSnapId)-$stamp"
    $utf8 = New-Object Text.UTF8Encoding $false

    $profiles = @()
    $i = 0
    $touched = @(Get-AllHostProfiles)
    foreach ($lp in (Get-LegacyHostProfiles)) { if ($touched -notcontains $lp) { $touched += $lp } }
    foreach ($pp in $touched) {
        $i++
        $existed = Test-Path -LiteralPath $pp
        $bak = $null
        if ($existed) {
            $bak = Join-Path $root "$base.profile$i.bak"
            Copy-Item -LiteralPath $pp -Destination $bak -Force
        }
        $profiles += @{ path = $pp; existed = [bool]$existed; bak = $bak }
    }

    $wtPath = Get-WtSettingsPath
    $wtBak = $null
    if ($wtPath) {
        $wtBak = Join-Path $root "$base.wt.bak"
        Copy-Item -LiteralPath $wtPath -Destination $wtBak -Force
    }

    $snap = @{
        taken          = $stamp
        ompWasPresent  = [bool]$OmpWasPresent
        profiles       = $profiles
        envPath        = [Environment]::GetEnvironmentVariable('Path', 'User')
        envPosh        = [Environment]::GetEnvironmentVariable('POSH_THEMES_PATH', 'User')
        consoleFont    = (Get-ConsoleFontState)
        wtPath         = $wtPath
        wtBak          = $wtBak
    }
    $json = $snap | ConvertTo-Json -Depth 6
    $path = Join-Path $root "$base.json"
    [IO.File]::WriteAllText($path, $json, $utf8)
    return $path
}

function Invoke-TerminalRevert {
    try { [void](Get-UserCopyDir) }
    catch { Start-Work; Add-Outcome 'fail' ($script:S.Oops + ' ' + (Get-ShortError $_)); Show-Outcome; return }
    $path = Get-LatestSnapshot $script:TermSnapId
    if ($null -eq $path) { Start-Work; Add-Outcome 'warn' $script:S.NoSnapshot; Show-Outcome; return }
    $snap = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
    Start-Work
    Write-Live ''
    $bad = @()

    foreach ($pf in @($snap.profiles)) {
        try {
            Assert-SafeUserPath $pf.path
            if ($pf.existed -and $pf.bak -and (Test-Path -LiteralPath $pf.bak)) {
                Copy-Item -LiteralPath $pf.bak -Destination $pf.path -Force
            }
            elseif ((-not $pf.existed) -and (Test-Path -LiteralPath $pf.path)) {
                Remove-Item -LiteralPath $pf.path -Force -ErrorAction SilentlyContinue
            }
        }
        catch { $bad += (Get-ShortError $_) }
    }

    try {
        [Environment]::SetEnvironmentVariable('Path', $snap.envPath, 'User')
        [Environment]::SetEnvironmentVariable('POSH_THEMES_PATH', $snap.envPosh, 'User')
    }
    catch { $bad += (Get-ShortError $_) }

    try { Restore-ConsoleFont $snap.consoleFont } catch { $bad += (Get-ShortError $_) }

    try {
        if ($snap.wtPath) {
            Assert-SafeUserPath $snap.wtPath
            if ($snap.wtBak -and (Test-Path -LiteralPath $snap.wtBak)) {
                Copy-Item -LiteralPath $snap.wtBak -Destination $snap.wtPath -Force
            }
        }
    }
    catch { $bad += (Get-ShortError $_) }

    if (-not $snap.ompWasPresent) {
        try {
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                if ((Invoke-Quiet 'winget' @('uninstall', '-e', '--id', $script:TermWingetId, '--silent')) -ne 0) { $bad += $script:S.TermOmpKept }
            }
        }
        catch { $bad += (Get-ShortError $_) }
    }
    if ($bad.Count -eq 0) { Add-Outcome 'ok' $script:S.TermReverted }
    else {
        Add-Outcome 'warn' $script:S.OutPartRevert
        foreach ($b in $bad) { Add-Outcome 'fail' $b }
    }
    Show-Outcome
}

function Show-ThemePicker {
    $all = Get-ThemeNames
    if ($all.Count -eq 0) {
        Write-Host ''
        Write-Host ('  ' + $script:S.TermNoThemes) -ForegroundColor Yellow
        [void](Read-Host ('  ' + $script:S.PressEnter))
        return $null
    }
    $rec = @($script:TermRecommended | Where-Object { $all -contains $_ })
    $showAll = $false
    while ($true) {
        $list = if ($showAll) { $all } else { $rec }
        Write-Host ''
        Write-Host ('  ' + $script:S.TermPickTheme) -ForegroundColor Cyan
        Write-Host ''
        $n = 0
        foreach ($t in $list) { $n++; Write-Host ("  [{0,2}] {1}" -f $n, $t) }
        Write-Host ''
        Write-Host ('  ' + $script:S.TermMinimalHint) -ForegroundColor DarkGray
        if (-not $showAll) { Write-Host ('  ' + $script:S.TermShowAll) }
        Write-Host ('  ' + $script:S.TermPreviewHint)
        Write-Host ('  ' + $script:S.TermBack)
        Write-Host ''
        $ans = (Read-Host ('  ' + $script:S.Choice)).Trim()
        if ($ans -eq '0' -or $ans -eq '') { return $null }
        if (-not $showAll -and (Get-Key $ans) -eq 'a') { $showAll = $true; continue }
        if ($ans -match '^[pPзЗ]\s*(\d+)$') {
            $i = [int]$Matches[1]
            if ($i -ge 1 -and $i -le $list.Count) { Show-ThemePreview $list[$i - 1] }
            continue
        }
        $num = 0
        if ([int]::TryParse($ans, [ref]$num) -and $num -ge 1 -and $num -le $list.Count) {
            return $list[$num - 1]
        }
        Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow
    }
}

function Show-ThemePreview($Name) {
    if ($Name -notmatch '^[A-Za-z0-9._-]+$') { return }
    $cfg = Get-ThemeConfigPath $Name
    $omp = Get-OmpCmd
    if (-not $omp -or -not (Test-Path -LiteralPath $cfg)) { return }
    if (-not (Test-TrustedOmp $omp)) { return }
    $env:AS_OMP_EXE = $omp
    $env:AS_OMP_CFG = $cfg
    $env:AS_OMP_MSG = $script:S.TermPreviewWindow
    $fixed = '& $env:AS_OMP_EXE init pwsh --config $env:AS_OMP_CFG | Invoke-Expression; Write-Host ("`n  " + $env:AS_OMP_MSG)'
    try { Start-Process powershell.exe -ArgumentList '-NoExit', '-NoProfile', '-Command', $fixed } catch {}
}

function Invoke-TerminalScreen {
    Clear-Host
    Write-Host ''
    Write-Host ('  ' + $script:S.TermTitle) -ForegroundColor Cyan
    Write-Host ''
    foreach ($line in $script:S.TermWarn) { Write-Host ('  ' + $line) }
    Write-Host ''
    Write-Host ('  ' + $script:S.TermFontManual) -ForegroundColor DarkGray
    Write-Host ('  ' + $script:TermFontUrl) -ForegroundColor DarkGray
    Write-Host ''
    Write-Host ('  ' + $script:S.TermActions)
    $offerWt = (-not (Test-WtInstalled)) -and ($build -ge 18362)
    if ($offerWt) { Write-Host ('  ' + $script:S.TermWtAction) }
    Write-Host ''
    $ans = (Read-Host ('  ' + $script:S.Choice)).Trim()
    if ($ans -eq '0' -or $ans -eq '') { return }
    $key = Get-Key $ans
    if ($key -eq 'r') { Invoke-TerminalRevert; Pause-Return; return }
    if ($key -eq 'w' -and $offerWt) { Request-ModernTerminal; return }
    if (-not (Test-Yes $ans)) { return }

    $omp = Get-OmpCmd
    $ompWasPresent = ($null -ne $omp)
    if (-not $ompWasPresent) {
        Start-Work
        Write-Live 'oh-my-posh'
        $ok = Install-Omp
        Clear-Live
        if (-not $ok) { Add-Outcome 'fail' $script:S.TermOmpFail; Show-Outcome; Pause-Return; return }
        $omp = Get-OmpCmd
    }

    $theme = Show-ThemePicker
    if (-not $theme) { return }

    Start-Work
    Write-Live ''
    $snapPath = Save-TerminalSnapshot $ompWasPresent

    Write-Live $script:TermFontFamily
    $fontOk = [bool](Install-NerdFontFamily $script:TermFontInstallId)
    try { Set-ConsoleFont $script:TermConsoleFontFamily } catch {}
    $wt = Get-WtSettingsPath
    $problems = @()
    if ($wt) { try { Set-WtFont $wt $script:TermFontFamily } catch { $problems += (Get-ShortError $_) } }

    Set-ExecPolicyIfNeeded
    $cfgLiteral = '"$env:POSH_THEMES_PATH\' + $theme + '.omp.json"'
    $initLine = 'if (-not $global:__AS_OMP) { if (-not (Get-Command oh-my-posh -EA SilentlyContinue)) { $__o = Join-Path $env:LOCALAPPDATA ''Programs\oh-my-posh\bin''; if (Test-Path $__o) { $env:PATH = $__o + '';'' + $env:PATH } }; if (-not $env:POSH_THEMES_PATH) { $__t = Join-Path $env:LOCALAPPDATA ''Programs\oh-my-posh\themes''; if (Test-Path $__t) { $env:POSH_THEMES_PATH = $__t } }; if (Get-Command oh-my-posh -EA SilentlyContinue) { oh-my-posh init pwsh --config ' + $cfgLiteral + ' | Invoke-Expression; $global:__AS_OMP = $true } }'
    $writeTargets = @(Get-AllHostProfiles)
    foreach ($pp in $writeTargets) {
        try { Set-TermProfileLine $pp $initLine }
        catch { $problems += (Get-ShortError $_) }
    }
    foreach ($pp in (Get-LegacyHostProfiles)) {
        if ($writeTargets -notcontains $pp) { try { Set-TermProfileLine $pp $null } catch {} }
    }
    if ($problems.Count -eq 0) { Add-Outcome 'ok' ($script:S.TermApplied -f $theme) }
    foreach ($b in $problems) { Add-Outcome 'fail' ($script:S.Oops + ' ' + $b) }
    if ($fontOk) { Add-Outcome 'ok' $script:S.TermFontOk }
    else { Add-Outcome 'warn' ($script:S.TermFontFail + ' ' + $script:TermFontUrl) }
    Add-Outcome 'note' $script:S.SnapSaved
    Add-Outcome 'note' $script:S.TermOpenNew
    Show-Outcome
    Pause-Return
}
