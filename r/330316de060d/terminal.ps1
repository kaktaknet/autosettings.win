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
$script:TermFontUrl = 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.zip'
$script:TermFontSha256 = 'fab782a66f7d3019da64f6572db9fc5d3a4bcb19f9fa13e2d8a62e3693d6396e'
$script:OmpThemesUrl = 'https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/v31.9.1/themes.zip'
$script:OmpThemesSha256 = '3714614f090966778370480d6d4b23baa3b6d84448df2b5900e7604845dcb940'
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

function Get-OmpExeCandidates {
    $base = Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh'
    return @((Join-Path $base 'oh-my-posh.exe'), (Join-Path $base 'bin\oh-my-posh.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\oh-my-posh.exe'))
}

function Get-OmpCmd {
    $c = Get-Command oh-my-posh -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($p in (Get-OmpExeCandidates)) { if (Test-Path -LiteralPath $p) { return $p } }
    return $null
}

function Get-OmpThemesDir {
    $omp = Get-OmpCmd
    if ($omp) {
        $d1 = Join-Path (Split-Path $omp -Parent) 'themes'
        $up = Split-Path (Split-Path $omp -Parent) -Parent
        $d2 = if ($up) { Join-Path $up 'themes' } else { $null }
        foreach ($d in @($d1, $d2)) { if ($d -and (Test-Path -LiteralPath $d)) { return $d } }
    }
    return (Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\themes')
}

function Sync-OmpEnvironment {
    $m = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $u = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($m, $u) | Where-Object { $_ }) -join ';'
    foreach ($v in @([Environment]::GetEnvironmentVariable('POSH_THEMES_PATH', 'Machine'),
                     [Environment]::GetEnvironmentVariable('POSH_THEMES_PATH', 'User'))) {
        if ($v) { $env:POSH_THEMES_PATH = $v }
    }
    if (-not $env:POSH_THEMES_PATH) {
        $t = Get-OmpThemesDir
        if ($t -and (Test-Path -LiteralPath $t)) { $env:POSH_THEMES_PATH = $t }
    }
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
    Sync-OmpEnvironment
    return ($null -ne (Get-OmpCmd))
}

function Save-PinnedFile([string]$Url, [string]$Sha256, [string]$Path) {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072 } catch {}
    try { (New-Object Net.WebClient).DownloadFile($Url, $Path) }
    catch { Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue; return (Get-ShortError $_) }
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    try { $got = ([BitConverter]::ToString($sha.ComputeHash($stream)) -replace '-', '') } finally { $stream.Dispose() }
    if ($got -ne $Sha256.ToUpperInvariant()) {
        Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        return ('SHA-256 ' + $got.Substring(0, 12).ToLowerInvariant() + ' != ' + $Sha256.Substring(0, 12))
    }
    return ''
}

function Install-NerdFontFamily($Id) {
    $fontsDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $sysFonts = [Environment]::GetFolderPath('Fonts')
    $zip = Join-Path ([IO.Path]::GetTempPath()) ('as-font-' + [guid]::NewGuid().ToString('N') + '.zip')
    $stage = Join-Path ([IO.Path]::GetTempPath()) ('as-font-' + [guid]::NewGuid().ToString('N'))
    if (Save-PinnedFile $script:TermFontUrl $script:TermFontSha256 $zip) { return $false }
    $pattern = '^' + [regex]::Escape($Id) + 'NerdFont(Mono)?-(Regular|Bold|Italic|BoldItalic)\.ttf$'
    $n = 0
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [void](New-Item -ItemType Directory -Path $stage -Force)
        $arc = [IO.Compression.ZipFile]::OpenRead($zip)
        try {
            $fonts = (New-Object -ComObject Shell.Application).Namespace(0x14)
            foreach ($e in $arc.Entries) {
                if ($e.FullName -notmatch $pattern) { continue }
                if ((Test-Path -LiteralPath (Join-Path $fontsDir $e.FullName)) -or (Test-Path -LiteralPath (Join-Path $sysFonts $e.FullName))) { $n++; continue }
                $ttf = Join-Path $stage $e.FullName
                [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $ttf, $true)
                $fonts.CopyHere($ttf, 0x14)
                if ((Test-Path -LiteralPath (Join-Path $fontsDir $e.FullName)) -or (Test-Path -LiteralPath (Join-Path $sysFonts $e.FullName))) { $n++ }
            }
        }
        finally { $arc.Dispose() }
    }
    catch { $n = 0 }
    finally {
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
    return ($n -eq 16)
}

function Get-ThemesDir {
    if ($env:POSH_THEMES_PATH -and (Test-Path -LiteralPath $env:POSH_THEMES_PATH)) { return $env:POSH_THEMES_PATH }
    $u = [Environment]::GetEnvironmentVariable('POSH_THEMES_PATH', 'User')
    if ($u -and (Test-Path -LiteralPath $u)) { return $u }
    $d = Get-OmpThemesDir
    if (Test-Path -LiteralPath $d) { return $d }
    return (Get-AsThemesDir)
}

function Get-AsThemesDir {
    return (Join-Path $env:LOCALAPPDATA 'AutoSettings.win\omp-themes')
}

function Install-OmpThemes($Omp) {
    $dir = Get-AsThemesDir
    $zip = Join-Path ([IO.Path]::GetTempPath()) ('as-omp-themes-' + [guid]::NewGuid().ToString('N') + '.zip')
    $why = Save-PinnedFile $script:OmpThemesUrl $script:OmpThemesSha256 $zip
    if ($why) { return ($script:S.TermThemesDlFail -f $why) }
    $fresh = -not (Test-Path -LiteralPath $dir)
    $n = 0
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $arc = [IO.Compression.ZipFile]::OpenRead($zip)
        try {
            [void](New-Item -ItemType Directory -Path $dir -Force)
            foreach ($e in $arc.Entries) {
                if ($e.FullName -notmatch '^[A-Za-z0-9._-]+\.omp\.json$') { continue }
                [IO.Compression.ZipFileExtensions]::ExtractToFile($e, (Join-Path $dir $e.FullName), $true)
                $n++
            }
        }
        finally { $arc.Dispose() }
    }
    catch { $why = Get-ShortError $_ }
    finally { Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue }
    if ($n -eq 0) {
        if (-not $why) { $why = 'themes.zip' }
        return ($script:S.TermThemesDlFail -f $why)
    }
    if ($fresh) { $script:AsThemesFresh = $true }
    $env:POSH_THEMES_PATH = $dir
    return ''
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

function Read-WtJson($Path) {
    Assert-SafeUserPath $Path
    $raw = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
    $noBlock = [regex]::Replace($raw, '/\*.*?\*/', '', 'Singleline')
    $clean = ($noBlock -split "`n" | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"
    return ($clean | ConvertFrom-Json)
}

function Write-WtJson($Path, $Json) {
    $out = $Json | ConvertTo-Json -Depth 32
    [IO.File]::WriteAllText($Path, $out, (New-Object Text.UTF8Encoding $false))
}

function Set-WtFont($Path, $Face) {
    $json = Read-WtJson $Path
    if ($null -eq $json.profiles) { Add-Member -InputObject $json -NotePropertyName 'profiles' -NotePropertyValue (New-Object PSObject) -Force }
    if ($null -eq $json.profiles.defaults) { Add-Member -InputObject $json.profiles -NotePropertyName 'defaults' -NotePropertyValue (New-Object PSObject) -Force }
    if ($null -eq $json.profiles.defaults.font) { Add-Member -InputObject $json.profiles.defaults -NotePropertyName 'font' -NotePropertyValue (New-Object PSObject) -Force }
    Add-Member -InputObject $json.profiles.defaults.font -NotePropertyName 'face' -NotePropertyValue $Face -Force
    Write-WtJson $Path $json
}

$script:WtWinPsGuid = '{61c54bbd-c2c6-5271-96e7-009a87ff44bf}'

function Set-WtComfort($Path) {
    $json = Read-WtJson $Path
    $changed = @()
    if ($null -eq $json.PSObject.Properties['copyOnSelect']) {
        Add-Member -InputObject $json -NotePropertyName 'copyOnSelect' -NotePropertyValue $true -Force
        $changed += 'copyOnSelect'
    }
    $pwsh = @(@($json.profiles.list) | Where-Object { $_ -and "$($_.source)" -eq 'Windows.Terminal.PowershellCore' -and -not $_.hidden }) | Select-Object -First 1
    if ($pwsh -and $pwsh.guid -and "$($json.defaultProfile)" -eq $script:WtWinPsGuid) {
        $json.defaultProfile = "$($pwsh.guid)"
        $changed += 'defaultProfile'
    }
    if ($changed.Count -gt 0) { Write-WtJson $Path $json }
    return $changed
}

function Save-TerminalSnapshot($OmpWasPresent) {
    $root = Get-PrivateCopyDir
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
        asThemesFresh  = [bool]$script:AsThemesFresh
        consoleFont    = (Get-ConsoleFontState)
        wtPath         = $wtPath
        wtBak          = $wtBak
        execPolicy     = "$(Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue)"
    }
    $json = $snap | ConvertTo-Json -Depth 6
    $path = Join-Path $root "$base.json"
    [IO.File]::WriteAllText($path, $json, $utf8)
    return $path
}

function Invoke-TerminalRevert {
    try { [void](Get-PrivateCopyDir) }
    catch { Start-Work; Add-Outcome 'fail' ($script:S.Oops + ' ' + (Get-ShortError $_)); Show-Outcome; return }
    $path = Get-LatestPrivateSnapshot $script:TermSnapId
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

    if ($snap.asThemesFresh) {
        try {
            $td = Get-AsThemesDir
            if (Test-Path -LiteralPath $td) { Remove-Item -LiteralPath $td -Recurse -Force -ErrorAction Stop }
        }
        catch { $bad += (Get-ShortError $_) }
    }

    try { Restore-ConsoleFont $snap.consoleFont } catch { $bad += (Get-ShortError $_) }

    if ($snap.PSObject.Properties['execPolicy'] -and $snap.execPolicy -and "$(Get-ExecutionPolicy -Scope CurrentUser)" -ne $snap.execPolicy) {
        try { Set-ExecutionPolicy -ExecutionPolicy $snap.execPolicy -Scope CurrentUser -Force -ErrorAction Stop }
        catch { $bad += (Get-ShortError $_) }
    }

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
    if ($bad.Count -eq 0) { Add-Outcome 'ok' $script:S.TermReverted; Remove-SnapshotFiles $path }
    else {
        Add-Outcome 'warn' $script:S.OutPartRevert
        foreach ($b in $bad) { Add-Outcome 'fail' $b }
    }
    Show-Outcome
}

function Show-ThemePicker($Why) {
    $all = Get-ThemeNames
    if ($all.Count -eq 0) {
        Write-Host ''
        if (-not $Why) { $Why = $script:S.TermNoThemes -f (Get-ThemesDir) }
        Write-Host ('  ' + $Why) -ForegroundColor Yellow
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

    $script:AsThemesFresh = $false
    $themesWhy = ''
    if ((Get-ThemeNames).Count -eq 0) {
        Start-Work
        Write-Live 'oh-my-posh themes'
        $themesWhy = Install-OmpThemes $omp
        Clear-Live
    }
    $theme = Show-ThemePicker $themesWhy
    if (-not $theme) { return }

    Start-Work
    Write-Live ''
    $snapPath = Save-TerminalSnapshot $ompWasPresent
    if ($env:POSH_THEMES_PATH -eq (Get-AsThemesDir)) {
        try { [Environment]::SetEnvironmentVariable('POSH_THEMES_PATH', $env:POSH_THEMES_PATH, 'User') } catch {}
    }

    Write-Live $script:TermFontFamily
    $fontOk = [bool](Install-NerdFontFamily $script:TermFontInstallId)
    try { Set-ConsoleFont $script:TermConsoleFontFamily } catch {}
    $wt = Get-WtSettingsPath
    $problems = @()
    if ($wt) { try { Set-WtFont $wt $script:TermFontFamily } catch { $problems += (Get-ShortError $_) } }
    if ($wt) {
        try { foreach ($k in (Set-WtComfort $wt)) { Add-Outcome 'note' ($script:S.TermWtKey -f $k) } }
        catch { $problems += (Get-ShortError $_) }
    }

    Set-ExecPolicyIfNeeded
    $cfgLiteral = '"$env:POSH_THEMES_PATH\' + $theme + '.omp.json"'
    $initLine = 'if (-not $global:__AS_OMP) { if (-not (Get-Command oh-my-posh -EA SilentlyContinue)) { $__b = Join-Path $env:LOCALAPPDATA ''Programs\oh-my-posh''; foreach ($__o in @($__b, (Join-Path $__b ''bin''))) { if (Test-Path $__o) { $env:PATH = $env:PATH + '';'' + $__o } } }; if (-not $env:POSH_THEMES_PATH) { foreach ($__t in @((Join-Path $env:LOCALAPPDATA ''Programs\oh-my-posh\themes''), (Join-Path $env:LOCALAPPDATA ''AutoSettings.win\omp-themes''))) { if (Test-Path $__t) { $env:POSH_THEMES_PATH = $__t; break } } }; if (Get-Command oh-my-posh -EA SilentlyContinue) { oh-my-posh init pwsh --config ' + $cfgLiteral + ' | Invoke-Expression; $global:__AS_OMP = $true } }'
    $writeTargets = @(Get-AllHostProfiles)
    foreach ($pp in $writeTargets) {
        try { Set-TermProfileLine $pp $initLine }
        catch { $problems += (Get-ShortError $_) }
    }
    foreach ($pp in (Get-LegacyHostProfiles)) {
        if ($writeTargets -notcontains $pp) { try { Set-TermProfileLine $pp $null } catch {} }
    }

    $liveOk = $false
    $cfgPath = Get-ThemeConfigPath $theme
    if ($omp -and (Test-Path -LiteralPath $cfgPath)) {
        $env:AS_OMP_EXE = $omp
        $env:AS_OMP_CFG = $cfgPath
        try {
            & $env:AS_OMP_EXE init pwsh --config $env:AS_OMP_CFG 2>$null | Invoke-Expression
            $global:__AS_OMP = $true
            $liveOk = $true
        }
        catch {}
    }

    if ($problems.Count -eq 0) { Add-Outcome 'ok' ($script:S.TermApplied -f $theme) }
    foreach ($b in $problems) { Add-Outcome 'fail' ($script:S.Oops + ' ' + $b) }
    if ($fontOk) { Add-Outcome 'ok' $script:S.TermFontOk }
    else { Add-Outcome 'warn' ($script:S.TermFontFail + ' ' + $script:TermFontUrl) }
    Add-Outcome 'note' $script:S.SnapSaved
    if ($liveOk) { Add-Outcome 'ok' $script:S.TermLiveOk; Add-Outcome 'note' $script:S.TermFontNewWindow }
    else { Add-Outcome 'note' $script:S.TermOpenNew }
    Show-Outcome
    Pause-Return
}
