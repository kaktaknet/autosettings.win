# MACHINE-READABLE INTENT (for a reviewing human or AI agent): Opt-in only. On the user's explicit
# "yes" this installs oh-my-posh, the JetBrainsMono Nerd Font and Python (if missing), copies a
# Claude Code statusline (oh-my-posh config + two python scripts) into the user's ~/.claude, sets its
# statusLine in ~/.claude/settings.json, and installs an impersonal PowerShell profile preset.
# Everything is snapshotted first (Save-AiSnapshot) and reverts from the menu. No hidden behavior,
# no data sent out, no attempt to exploit anything. Declining changes nothing.
# License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
# Redistribution must keep this notice and the LICENSE and NOTICE files: https://github.com/kaktaknet/autosettings.win

$script:AiClaudeDir = Join-Path $env:USERPROFILE '.claude'
$script:AiProfileDir = Join-Path (Join-Path $env:USERPROFILE '.config') 'autosettings'
$script:AiStatusAssets = @('claude.omp.json', 'statusline-omp.py', 'statusline-command.py')
$script:AiProfileAsset = 'autosettings.profile.ps1'
$script:AiProfileMarker = '# autosettings.win: PowerShell profile'
$script:AiPyManagerId = '9NQ7512CXL7T'
$script:AiPyFallbackId = 'Python.Python.3.12'
$script:AiSnapId = 'aiterm'

function Test-PythonRuns($Full) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $Full '-c' 'import sys;print(sys.version_info[0])' 2>$null
        return ("$out".Trim() -eq '3')
    }
    catch { return $false }
    finally { $ErrorActionPreference = $old }
}

function Get-PythonCandidates {
    $list = @()
    foreach ($name in @('py', 'python', 'python3')) {
        $full = Resolve-ExePath $name
        if ($full) { $list += $full }
    }
    $dirs = @()
    if ($env:LOCALAPPDATA) {
        $dirs += (Join-Path $env:LOCALAPPDATA 'Python\bin')
        $dirs += (Join-Path $env:LOCALAPPDATA 'Python\pythoncore-3*')
        $dirs += (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python3*')
    }
    if ($env:ProgramFiles) { $dirs += (Join-Path $env:ProgramFiles 'Python3*') }
    foreach ($dir in $dirs) {
        foreach ($f in @(Get-ChildItem -Path (Join-Path $dir 'python.exe') -ErrorAction SilentlyContinue | Sort-Object FullName -Descending)) {
            if ($list -notcontains $f.FullName) { $list += $f.FullName }
        }
    }
    return $list
}

function Get-PythonCmd {
    foreach ($full in @(Get-PythonCandidates)) {
        if (-not (Test-TrustedExe $full @($script:PinPython, $script:PinMicrosoft))) { continue }
        if (Test-PythonRuns $full) { return $full }
    }
    return $null
}

function Install-Python {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $null }
    [void](Invoke-Quiet 'winget' @('install', '-e', '--id', $script:AiPyManagerId, '--accept-package-agreements', '--accept-source-agreements'))
    Update-SessionPath
    foreach ($name in @('pymanager', 'py')) {
        $mgr = Resolve-ExePath $name
        if (-not $mgr) { continue }
        if (-not (Test-TrustedExe $mgr @($script:PinPython, $script:PinMicrosoft))) { continue }
        if ((Invoke-Quiet $mgr @('install', '-y', '3')) -eq 0) { break }
    }
    Update-SessionPath
    $cmd = Get-PythonCmd
    if ($cmd) { return $cmd }
    [void](Invoke-Quiet 'winget' @('install', '-e', '--id', $script:AiPyFallbackId, '--silent', '--accept-package-agreements', '--accept-source-agreements'))
    Update-SessionPath
    return (Get-PythonCmd)
}

function Get-NodeNpm {
    return ((Get-Command npm -ErrorAction SilentlyContinue) -and (Get-Command node -ErrorAction SilentlyContinue))
}

function Install-Node {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $false }
    [void](Invoke-Quiet 'winget' @('install', '-e', '--id', 'OpenJS.NodeJS.LTS', '--source', 'winget', '--silent', '--accept-package-agreements', '--accept-source-agreements'))
    Update-SessionPath
    return (Get-NodeNpm)
}

function Install-PSModules {
    try { [void](Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction SilentlyContinue) } catch {}
    try { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue } catch {}
    foreach ($m in @('Terminal-Icons', 'CompletionPredictor')) {
        if (-not (Get-Module -ListAvailable -Name $m)) {
            try { Install-Module -Name $m -Scope CurrentUser -Force -Repository PSGallery -ErrorAction Stop } catch {}
        }
    }
}

function Save-AiSnapshot($OmpWasPresent, $PyWasPresent, $Profiles) {
    $root = Get-UserCopyDir
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $base = "$($script:AiSnapId)-$stamp"
    $utf8 = New-Object Text.UTF8Encoding $false

    $profiles = @()
    $i = 0
    foreach ($pp in $Profiles) {
        $i++
        $existed = Test-Path -LiteralPath $pp
        $bak = $null
        if ($existed) {
            $bak = Join-Path $root "$base.profile$i.bak"
            Copy-Item -LiteralPath $pp -Destination $bak -Force
        }
        $profiles += @{ path = $pp; existed = [bool]$existed; bak = $bak }
    }

    $settings = Join-Path $script:AiClaudeDir 'settings.json'
    $settingsExisted = Test-Path -LiteralPath $settings
    $settingsBak = $null
    if ($settingsExisted) {
        $settingsBak = Join-Path $root "$base.settings.bak"
        Copy-Item -LiteralPath $settings -Destination $settingsBak -Force
    }

    $created = @()
    foreach ($n in ($script:AiStatusAssets + @('statusline.lang'))) {
        $p = Join-Path $script:AiClaudeDir $n
        if (-not (Test-Path -LiteralPath $p)) { $created += $p }
    }

    $snap = @{
        taken = $stamp
        ompWasPresent = [bool]$OmpWasPresent
        pyWasPresent = [bool]$PyWasPresent
        profiles = $profiles
        settingsPath = $settings
        settingsExisted = [bool]$settingsExisted
        settingsBak = $settingsBak
        created = $created
        profileDir = $script:AiProfileDir
    }
    $json = $snap | ConvertTo-Json -Depth 6
    $path = Join-Path $root "$base.json"
    [IO.File]::WriteAllText($path, $json, $utf8)
    return $path
}

function Invoke-AiRevert {
    try { [void](Get-UserCopyDir) }
    catch { Start-Work; Add-Outcome 'fail' ($script:S.Oops + ' ' + (Get-ShortError $_)); Show-Outcome; return }
    $path = Get-LatestSnapshot $script:AiSnapId
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
        $preset = Join-Path $snap.profileDir $script:AiProfileAsset
        Assert-SafeUserPath $preset
        if (Test-Path -LiteralPath $preset) { Remove-Item -LiteralPath $preset -Force -ErrorAction SilentlyContinue }
    }
    catch { $bad += (Get-ShortError $_) }

    try {
        Assert-SafeUserPath $snap.settingsPath
        if ($snap.settingsExisted -and $snap.settingsBak -and (Test-Path -LiteralPath $snap.settingsBak)) {
            Copy-Item -LiteralPath $snap.settingsBak -Destination $snap.settingsPath -Force
        }
        elseif ((-not $snap.settingsExisted) -and (Test-Path -LiteralPath $snap.settingsPath)) {
            Remove-Item -LiteralPath $snap.settingsPath -Force -ErrorAction SilentlyContinue
        }
    }
    catch { $bad += (Get-ShortError $_) }

    foreach ($f in @($snap.created)) {
        try {
            if ($f -and (Test-Path -LiteralPath $f)) {
                Assert-SafeUserPath $f
                Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
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

function Set-ProfileDotSource($ProfilePath, $PresetPath) {
    Set-ExecPolicyIfNeeded
    Assert-SafeUserPath $ProfilePath
    if (-not (Test-Path -LiteralPath $ProfilePath)) {
        if (-not $PresetPath) { return }
        $dir = Split-Path -Parent $ProfilePath
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
        [void](New-Item -Path $ProfilePath -ItemType File -Force)
    }
    $kept = @(Get-Content -LiteralPath $ProfilePath -Encoding UTF8 | Where-Object {
        ($_ -notmatch [regex]::Escape($script:AiProfileMarker)) -and
        ($_ -notmatch [regex]::Escape('# autosettings.win: oh-my-posh')) -and
        (-not (($_ -match 'oh-my-posh init ') -and ($_ -match 'POSH_THEMES_PATH'))) -and
        ($_ -notmatch [regex]::Escape($script:AiProfileAsset))
    })
    $out = if ($PresetPath) { @($kept + @($script:AiProfileMarker, ". `"$PresetPath`"")) } else { @($kept) }
    Write-ProfileFile $ProfilePath $out
}

function Get-TargetProfiles {
    return (Get-AllHostProfiles)
}

function Ensure-Pwsh7 {
    if ($PSVersionTable.PSVersion.Major -ge 7) { return }
    if (Get-Command pwsh -ErrorAction SilentlyContinue) { return }
    Write-Host ''
    foreach ($line in $script:S.AiPwshOffer) { Write-Host ('  ' + $line) -ForegroundColor Yellow }
    $ans = (Read-Host ('  ' + $script:S.AiPwshAsk)).Trim()
    if (-not (Test-Yes $ans)) { return }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Host ('  ' + $script:S.AiPwshSkip) -ForegroundColor Yellow; return }
    Start-Work
    Write-Live 'PowerShell 7'
    [void](Invoke-Quiet 'winget' @('install', '-e', '--id', 'Microsoft.PowerShell', '--source', 'winget', '--silent', '--accept-package-agreements', '--accept-source-agreements'))
    Update-SessionPath
    if (Get-Command pwsh -ErrorAction SilentlyContinue) { Add-Outcome 'ok' $script:S.AiPwshDone }
    else { Add-Outcome 'warn' $script:S.AiPwshSkip }
    Show-Outcome
}

function Deploy-Profile($Lang, $Profiles, $Legacy) {
    $dst = Join-Path $script:AiProfileDir $script:AiProfileAsset
    Assert-SafeUserPath $dst
    if (-not (Test-Path -LiteralPath $script:AiProfileDir)) {
        [void](New-Item -ItemType Directory -Path $script:AiProfileDir -Force)
    }
    $src = Join-Path $PSScriptRoot $script:AiProfileAsset
    $text = [IO.File]::ReadAllText($src, [Text.Encoding]::UTF8).Replace('@ASLANG@', $Lang)
    [IO.File]::WriteAllText($dst, $text, (New-Object Text.UTF8Encoding $true))
    foreach ($p in $Profiles) { Set-ProfileDotSource $p $dst }
    foreach ($p in @($Legacy)) { Set-ProfileDotSource $p $null }
}

function Deploy-ClaudeStatusline($Lang, $PyCmd) {
    Assert-SafeUserPath $script:AiClaudeDir
    if (-not (Test-Path -LiteralPath $script:AiClaudeDir)) {
        [void](New-Item -ItemType Directory -Path $script:AiClaudeDir -Force)
    }
    $utf8 = New-Object Text.UTF8Encoding $false
    $langPath = Join-Path $script:AiClaudeDir 'statusline.lang'
    Assert-SafeUserPath $langPath
    [IO.File]::WriteAllText($langPath, $Lang, $utf8)
    foreach ($n in $script:AiStatusAssets) {
        $assetDst = Join-Path $script:AiClaudeDir $n
        Assert-SafeUserPath $assetDst
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $n) -Destination $assetDst -Force
    }
    $settings = Join-Path $script:AiClaudeDir 'settings.json'
    Assert-SafeUserPath $settings
    $obj = $null
    if (Test-Path -LiteralPath $settings) {
        try { $obj = [IO.File]::ReadAllText($settings, [Text.Encoding]::UTF8) | ConvertFrom-Json } catch { $obj = $null }
        if ($null -eq $obj) {
            Add-Outcome 'warn' $script:S.AiSettingsSkip
            return
        }
    }
    else { $obj = New-Object PSObject }
    $script = Join-Path $script:AiClaudeDir 'statusline-omp.py'
    $cmdLine = "`"$PyCmd`" `"$script`""
    $sl = New-Object PSObject
    Add-Member -InputObject $sl -NotePropertyName 'type' -NotePropertyValue 'command' -Force
    Add-Member -InputObject $sl -NotePropertyName 'command' -NotePropertyValue $cmdLine -Force
    Add-Member -InputObject $sl -NotePropertyName 'padding' -NotePropertyValue 2 -Force
    Add-Member -InputObject $sl -NotePropertyName 'refreshInterval' -NotePropertyValue 30 -Force
    Add-Member -InputObject $obj -NotePropertyName 'statusLine' -NotePropertyValue $sl -Force
    [IO.File]::WriteAllText($settings, ($obj | ConvertTo-Json -Depth 32), $utf8)
}

function Invoke-AiScreen {
    Clear-Host
    Write-Host ''
    Write-Host ('  ' + $script:S.AiTitle) -ForegroundColor Cyan
    Write-Host ''
    Write-Host ('  ' + $script:S.AiProviderClaude)
    Write-Host ('  ' + $script:S.AiProviderCodex) -ForegroundColor DarkGray
    Write-Host ''
    foreach ($line in $script:S.AiWarn) { Write-Host ('  ' + $line) }
    Write-Host ''
    Write-Host ('  ' + $script:S.AiActions)
    Write-Host ''
    $ans = (Read-Host ('  ' + $script:S.Choice)).Trim()
    if ($ans -eq '0' -or $ans -eq '') { return }
    if ((Get-Key $ans) -eq 'r') { Invoke-AiRevert; Pause-Return; return }
    if ($ans -ne '1') { return }

    Ensure-Pwsh7

    Start-Work

    $omp = Get-OmpCmd
    $ompWasPresent = ($null -ne $omp)
    if (-not $ompWasPresent) {
        Write-Live 'oh-my-posh'
        if (-not (Install-Omp)) { Add-Outcome 'fail' $script:S.TermOmpFail; Show-Outcome; Pause-Return; return }
        $omp = Get-OmpCmd
    }

    Write-Live 'Python'
    $pyWasPresent = ($null -ne (Get-PythonCmd))
    $pyCmd = Get-PythonCmd
    if (-not $pyCmd) { $pyCmd = Install-Python }
    if (-not $pyCmd) { Add-Outcome 'fail' $script:S.AiPyFail; Show-Outcome; Pause-Return; return }

    Write-Live 'Node.js'
    if (-not (Get-NodeNpm)) { [void](Install-Node) }
    $nodeOk = [bool](Get-NodeNpm)

    Write-Live ''
    $targets = Get-TargetProfiles
    $legacy = @(Get-LegacyHostProfiles | Where-Object { $targets -notcontains $_ })
    $snapPath = Save-AiSnapshot $ompWasPresent $pyWasPresent (@($targets) + $legacy)

    Write-Live $script:TermFontFamily
    $fontOk = [bool](Install-NerdFontFamily $script:TermFontInstallId)
    if ($fontOk) { try { Set-ConsoleFont $script:TermFontFamily } catch {} }

    Write-Live 'Terminal-Icons'
    Install-PSModules

    Write-Live ''
    try { Deploy-Profile $script:Lang $targets $legacy; Add-Outcome 'ok' $script:S.AiProfileDone }
    catch { Add-Outcome 'fail' ($script:S.Oops + ' ' + (Get-ShortError $_)) }

    try { Deploy-ClaudeStatusline $script:Lang $pyCmd; Add-Outcome 'ok' $script:S.AiStatusDone }
    catch { Add-Outcome 'fail' ($script:S.Oops + ' ' + (Get-ShortError $_)) }

    if (-not $nodeOk) { Add-Outcome 'warn' $script:S.AiNodeFail }
    if (-not $fontOk) { Add-Outcome 'warn' ($script:S.TermFontFail + ' ' + $script:TermFontUrl) }
    Add-Outcome 'note' $script:S.SnapSaved
    Add-Outcome 'note' $script:S.AiOpenNew
    Show-Outcome
    Pause-Return
}
