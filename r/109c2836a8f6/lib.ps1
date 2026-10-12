$script:SnapshotBase = Join-Path $env:ProgramData 'AutoSettings.win'
$script:SnapshotRoot = Join-Path $script:SnapshotBase 'snapshots'
$script:UserCopyBase = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'AutoSettings.win'
$script:UserCopyRoot = Join-Path $script:UserCopyBase 'backups'
$script:AllowedTypes = @('DWord', 'String')

function Protect-Dir($Path) {
    $admins = New-Object Security.Principal.SecurityIdentifier 'S-1-5-32-544'
    $system = New-Object Security.Principal.SecurityIdentifier 'S-1-5-18'
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)
    $acl.SetOwner($admins)
    foreach ($sid in @($admins, $system)) {
        $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule(
            $sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')))
    }
    Set-Acl -LiteralPath $Path -AclObject $acl
}

function Test-DirSafe($Path) {
    $allowed = @('S-1-5-32-544', 'S-1-5-18')
    try {
        $acl = Get-Acl -LiteralPath $Path
        $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
        if ($allowed -notcontains $owner) { return $false }
        foreach ($rule in $acl.Access) {
            if ($rule.AccessControlType -ne 'Allow') { continue }
            $sid = $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
            if ($allowed -notcontains $sid -and $sid -ne 'S-1-3-0') { return $false }
        }
    }
    catch { return $false }
    return $true
}

function Test-NoReparse($Path) {
    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        return (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint))
    }
    catch { return $false }
}

function Assert-SafeUserPath($Path) {
    $cur = $Path
    $seen = @{}
    while ($cur -and -not $seen.ContainsKey($cur)) {
        $seen[$cur] = $true
        if (Test-Path -LiteralPath $cur) {
            if (-not (Test-NoReparse $cur)) { throw "reparse point in path: $cur" }
        }
        $parent = Split-Path -Parent $cur
        if (-not $parent -or $parent -eq $cur) { break }
        $cur = $parent
    }
}

function Write-ProfileFile($Path, $Lines) {
    $arr = @($Lines)
    $enc = New-Object Text.UTF8Encoding $true
    if ($arr.Count -eq 0) { [IO.File]::WriteAllText($Path, '', $enc) }
    else { [IO.File]::WriteAllLines($Path, [string[]]$arr, $enc) }
}

function Get-UserCopyDir {
    foreach ($dir in @($script:UserCopyBase, $script:UserCopyRoot)) {
        if (Test-Path -LiteralPath $dir) {
            if (-not (Test-NoReparse $dir)) { throw "user copy path is a reparse point: $dir" }
        }
        else {
            [void](New-Item -ItemType Directory -Path $dir -ErrorAction Stop)
        }
    }
    return $script:UserCopyRoot
}

function Get-SnapshotDir {
    foreach ($dir in @($script:SnapshotBase, $script:SnapshotRoot)) {
        if (-not (Test-Path -LiteralPath $dir)) {
            [void](New-Item -ItemType Directory -Path $dir -Force)
            Protect-Dir $dir
        }
    }
    foreach ($dir in @($script:SnapshotBase, $script:SnapshotRoot)) {
        if (-not (Test-DirSafe $dir)) {
            throw ($script:S.SnapUnsafe -f $dir)
        }
    }
    return $script:SnapshotRoot
}

function Get-CurrentState($Setting) {
    $state = @{ KeyExists = $false; ValueExists = $false; Data = $null }
    if (Test-Path -LiteralPath $Setting.path) {
        $state.KeyExists = $true
        $item = Get-ItemProperty -LiteralPath $Setting.path -Name $Setting.name -ErrorAction SilentlyContinue
        if ($null -ne $item) {
            $prop = $item.PSObject.Properties[$Setting.name]
            if ($null -ne $prop) {
                $state.ValueExists = $true
                $state.Data = $prop.Value
            }
        }
    }
    return $state
}

function Test-Applied($Setting) {
    $state = Get-CurrentState $Setting
    if ($Setting.type -eq 'Remove') { return (-not $state.ValueExists) }
    if (-not $state.ValueExists) { return $false }
    return ("$($state.Data)" -eq "$($Setting.value)")
}

function Set-One($Setting) {
    if ($Setting.type -eq 'Remove') {
        if (Test-Path -LiteralPath $Setting.path) {
            Remove-ItemProperty -LiteralPath $Setting.path -Name $Setting.name -ErrorAction SilentlyContinue
        }
        return
    }
    if (-not (Test-Path -LiteralPath $Setting.path)) {
        [void](New-Item -Path $Setting.path -Force)
    }
    [void](New-ItemProperty -LiteralPath $Setting.path -Name $Setting.name `
        -PropertyType $Setting.type -Value $Setting.value -Force)
}

function Restore-One($Entry) {
    if ($Entry.ValueExists) {
        if ($script:AllowedTypes -notcontains "$($Entry.Type)") {
            Write-Host ("  " + ($script:S.SkipType -f $Entry.Type, $Entry.Path, $Entry.Name)) -ForegroundColor Yellow
            return
        }
        if (-not (Test-Path -LiteralPath $Entry.Path)) { [void](New-Item -Path $Entry.Path -Force) }
        [void](New-ItemProperty -LiteralPath $Entry.Path -Name $Entry.Name `
            -PropertyType $Entry.Type -Value $Entry.Data -Force)
        return
    }
    if (Test-Path -LiteralPath $Entry.Path) {
        Remove-ItemProperty -LiteralPath $Entry.Path -Name $Entry.Name -ErrorAction SilentlyContinue
        if (-not $Entry.KeyExists) {
            $key = Get-Item -LiteralPath $Entry.Path -ErrorAction SilentlyContinue
            if ($null -ne $key -and $key.ValueCount -eq 0 -and $key.SubKeyCount -eq 0) {
                Remove-Item -LiteralPath $Entry.Path -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Split-ByHive($Settings) {
    $user = @(); $machine = @()
    foreach ($s in @($Settings)) {
        if ("$($s.path)" -like 'HKLM:*') { $machine += $s } else { $user += $s }
    }
    return @{ User = $user; Machine = $machine }
}

function New-SnapshotEntries($Settings) {
    $entries = @()
    foreach ($s in @($Settings)) {
        $cur = Get-CurrentState $s
        $entries += @{
            Path = $s.path; Name = $s.name; Type = $s.type
            KeyExists = $cur.KeyExists; ValueExists = $cur.ValueExists; Data = $cur.Data
        }
    }
    return $entries
}

function Write-SnapshotFile($Entries, $SnapId, $Stamp, $Dir) {
    $path = Join-Path $Dir "$SnapId-$Stamp.json"
    $json = @{ module = $SnapId; taken = $Stamp; entries = $Entries } | ConvertTo-Json -Depth 5
    $utf8 = New-Object Text.UTF8Encoding $false
    $bytes = $utf8.GetBytes($json)
    $fs = [IO.File]::Open($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Dispose() }
    return $path
}

function Get-LatestIn($Root, $SnapId) {
    if (-not (Test-Path -LiteralPath $Root)) { return $null }
    $file = Get-ChildItem -LiteralPath $Root -Filter "$SnapId-*.json" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($null -eq $file) { return $null }
    return $file.FullName
}

function Save-UserSnapshot($UserSettings, $SnapId, $Stamp) {
    if (@($UserSettings).Count -eq 0) { return $null }
    $dir = Get-UserCopyDir
    return (Write-SnapshotFile (New-SnapshotEntries $UserSettings) $SnapId $Stamp $dir)
}

function Save-MachineSnapshot($MachineSettings, $SnapId, $Stamp) {
    if (@($MachineSettings).Count -eq 0) { return $null }
    $dir = Get-SnapshotDir
    return (Write-SnapshotFile (New-SnapshotEntries $MachineSettings) $SnapId $Stamp $dir)
}

function Get-LatestUserSnapshot($SnapId)    { return (Get-LatestIn $script:UserCopyRoot $SnapId) }
function Get-LatestMachineSnapshot($SnapId) { return (Get-LatestIn $script:SnapshotRoot $SnapId) }
function Get-LatestSnapshot($SnapId)        { return (Get-LatestIn $script:UserCopyRoot $SnapId) }

function Invoke-HklmHelper($Mode, $SnapSet, $ApplySet, $SnapId, $Stamp) {
    $root = $PSScriptRoot
    $sha = [Security.Cryptography.SHA256]::Create()
    $manifestBytes = [IO.File]::ReadAllBytes((Join-Path $root 'manifest.json'))
    $manifestSha = ([BitConverter]::ToString($sha.ComputeHash($manifestBytes)) -replace '-', '')
    if (-not $script:ManifestPin) { throw 'manifest pin is missing (loader did not pass it)' }
    if ($manifestSha -ne "$($script:ManifestPin)") { throw 'manifest does not match the pinned checksum' }
    $manifest = [Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json
    $readVerified = {
        param($name)
        $entry = $manifest.files | Where-Object { $_.name -eq $name } | Select-Object -First 1
        if ($null -eq $entry) { throw "no manifest entry for $name" }
        $bytes = [IO.File]::ReadAllBytes((Join-Path $root $name))
        $hex = ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '')
        if ($hex -ne $entry.sha256) { throw "checksum mismatch for $name" }
        return ([Text.Encoding]::UTF8.GetString($bytes)).TrimStart([char]0xFEFF)
    }
    $libSrc    = & $readVerified 'lib.ps1'
    $helperSrc = & $readVerified 'hklm-helper.ps1'

    $resultPath = Join-Path $root ('helper-result-' + [guid]::NewGuid().ToString('N') + '.json')
    $payload = @{
        Mode = $Mode; SnapId = $SnapId; Stamp = $Stamp
        SnapSet = @($SnapSet); ApplySet = @($ApplySet); ResultPath = $resultPath
    } | ConvertTo-Json -Depth 6 -Compress
    $payloadB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payload))

    $full = $libSrc + "`n" +
        "`$Hk = ConvertFrom-Json ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$payloadB64')))`n" +
        $helperSrc
    $utf8 = New-Object Text.UTF8Encoding $false
    $fullBytes = $utf8.GetBytes($full)
    $scriptPath = Join-Path $root ('helper-run-' + [guid]::NewGuid().ToString('N') + '.ps1')
    [IO.File]::WriteAllBytes($scriptPath, $fullBytes)
    $fullSha = ([BitConverter]::ToString($sha.ComputeHash($fullBytes)) -replace '-', '')

    $pathB64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($scriptPath))
    $boot = "`$p=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$pathB64'));`$h='$fullSha';" +
        "`$b=[IO.File]::ReadAllBytes(`$p);" +
        "`$x=([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash(`$b)) -replace '-','');" +
        "if(`$x -ne `$h){exit 9};" +
        "Invoke-Expression ([Text.Encoding]::UTF8.GetString(`$b))"
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($boot))

    $exit = $null
    try {
        $p = Start-Process (Get-HostExe) -Verb RunAs -Wait -PassThru -WindowStyle Hidden -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $enc)
        $exit = $p.ExitCode
    }
    finally {
        Remove-Item -LiteralPath $scriptPath -Force -ErrorAction SilentlyContinue
    }
    $res = $null
    if (Test-Path -LiteralPath $resultPath) {
        try { $res = [IO.File]::ReadAllText($resultPath, [Text.Encoding]::UTF8) | ConvertFrom-Json } catch {}
        Remove-Item -LiteralPath $resultPath -Force -ErrorAction SilentlyContinue
    }
    return @{ ExitCode = $exit; Result = $res }
}

function Test-Yes([string]$Answer) {
    $a = "$Answer".Trim().ToLower()
    return ($a -eq 'y' -or $a -eq 'yes' -or $a -eq 'д' -or $a -eq 'да')
}

function Get-ShortError($Err) {
    $m = "$($Err.Exception.Message)" -split "`r?`n" | Select-Object -First 1
    if ($m.Length -gt 160) { $m = $m.Substring(0, 160) + '...' }
    return $m
}

function Invoke-Quiet($Exe, $Arguments) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $Exe @Arguments 2>&1 | Out-Null; return $LASTEXITCODE }
    catch { return 1 }
    finally { $ErrorActionPreference = $old }
}

function Get-HostExe {
    $system = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    try {
        $path = (Get-Process -Id $PID -ErrorAction Stop).Path
        if ($path -and (Test-Path -LiteralPath $path)) {
            $full = [IO.Path]::GetFullPath($path)
            $inAdminDir = $false
            foreach ($dir in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:SystemRoot)) {
                if ($dir -and $full.StartsWith(($dir.TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) { $inAdminDir = $true }
            }
            if ($inAdminDir) {
                $sig = Get-AuthenticodeSignature -LiteralPath $full -ErrorAction Stop
                if ($sig.Status -eq 'Valid' -and $sig.SignerCertificate -and
                    $sig.SignerCertificate.Subject -match '(^|,\s*)O=Microsoft Corporation(,|$)') { return $full }
            }
        }
    } catch {}
    return $system
}

function Read-ElevatedLog($Path) {
    $out = @()
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $out }
    try { $text = [IO.File]::ReadAllText($Path) } catch { return $out }
    $inside = $false
    foreach ($line in ($text -split "`r?`n")) {
        if ($line -match '^\*{10,}\s*$') { $inside = -not $inside; continue }
        if ($inside) { continue }
        $t = $line.TrimEnd()
        if ($t -match '^\s*$') { continue }
        if ($t -match 'Нажмите Enter|Press Enter|^\s*Enter:?\s*$|^Transcript started|^Транскрибирование|^PS>|^>> |^(True|False)$') { continue }
        if ($t -match '^\s*(\+ |At line:|Line \||\||~|\d+ \||Exception:|CategoryInfo|FullyQualifiedErrorId|ScriptStackTrace|TerminatingError)') { continue }
        $out += $t.TrimStart()
    }
    if ($out.Count -gt 40) { $out = @($out[($out.Count - 40)..($out.Count - 1)]) }
    return $out
}

function Show-ElevatedReport($Rc) {
    $en = ($script:Lang -eq 'en')
    Write-Host ''
    if ($en) { Write-Host '  Result:' -ForegroundColor Cyan }
    else { Write-Host '  Результат:' -ForegroundColor Cyan }
    $lines = @($script:LastElevatedLog)
    foreach ($l in $lines) {
        $color = 'Gray'
        if ($l -match '^\[(OK|ОК)\]') { $color = 'Green' }
        elseif ($l -match '^\[(!!|!|ERR)\]') { $color = 'Red' }
        Write-Host "    $l" -ForegroundColor $color
    }
    if ($lines.Count -eq 0) {
        if ($en) { Write-Host '    (no details)' -ForegroundColor DarkGray }
        else { Write-Host '    (подробностей нет)' -ForegroundColor DarkGray }
    }
    Write-Host ''
    $saidOk = @($lines | Where-Object { $_ -match '^\[(OK|ОК)\]' }).Count -gt 0
    $saidBad = @($lines | Where-Object { $_ -match '^\[(!!|ERR)\]' }).Count -gt 0
    $done = ($Rc -eq 0) -or ($Rc -ne 8 -and $Rc -ne 9 -and $saidOk)
    if ($done -and $saidBad) {
        if ($en) { Write-Host '  [!] Not everything was done. What failed is above; try again.' -ForegroundColor Yellow }
        else { Write-Host '  [!] Сделано не всё. Что не получилось - выше; попробуйте ещё раз.' -ForegroundColor Yellow }
    }
    elseif ($done) {
        if ($en) { Write-Host '  [OK] Done.' -ForegroundColor Green }
        else { Write-Host '  [OK] Готово.' -ForegroundColor Green }
    }
    elseif ($Rc -eq 9) {
        if ($en) { Write-Host '  [!!] The downloaded files are damaged, so nothing was run. Start the installer again.' -ForegroundColor Red }
        else { Write-Host '  [!!] Скачанные файлы повреждены, поэтому ничего не запускали. Запустите установщик заново.' -ForegroundColor Red }
    }
    else {
        if ($en) { Write-Host '  [!!] That did not work. The reason is above; try again.' -ForegroundColor Red }
        else { Write-Host '  [!!] Не получилось. Причина - выше; попробуйте ещё раз.' -ForegroundColor Red }
    }
    Write-Host ''
    if ($en) { [void](Read-Host '  Press Enter to continue') }
    else { [void](Read-Host '  Нажмите Enter, чтобы продолжить') }
}

function Invoke-VerifiedElevated($Name, $ArgTokens) {
    $root = $PSScriptRoot
    $sha = [Security.Cryptography.SHA256]::Create()
    $manifestBytes = [IO.File]::ReadAllBytes((Join-Path $root 'manifest.json'))
    $manifestSha = ([BitConverter]::ToString($sha.ComputeHash($manifestBytes)) -replace '-', '')
    if (-not $script:ManifestPin) { throw 'manifest pin is missing (loader did not pass it)' }
    if ($manifestSha -ne "$($script:ManifestPin)") { throw 'manifest does not match the pinned checksum' }
    $manifest = [Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json
    $entry = $manifest.files | Where-Object { $_.name -eq $Name } | Select-Object -First 1
    if ($null -eq $entry) { throw "no manifest entry for $Name" }
    $bytes = [IO.File]::ReadAllBytes((Join-Path $root $Name))
    $hex = ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '')
    if ($hex -ne $entry.sha256) { throw "checksum mismatch for $Name" }

    $utf8 = New-Object Text.UTF8Encoding $false
    $scriptPath = Join-Path $root ('mod-run-' + [guid]::NewGuid().ToString('N') + '.ps1')
    [IO.File]::WriteAllBytes($scriptPath, $bytes)
    $fullSha = ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '')
    $pathB64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($scriptPath))
    $argLine = ($ArgTokens -join ' ')
    $logPath = Join-Path $root ('mod-log-' + [guid]::NewGuid().ToString('N') + '.txt')
    $logB64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($logPath))
    $script:LastElevatedLog = @()
    $boot = "`$p=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$pathB64'));`$h='$fullSha';" +
        "`$b=[IO.File]::ReadAllBytes(`$p);" +
        "`$x=([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash(`$b)) -replace '-','');" +
        "if(`$x -ne `$h){exit 9};" +
        "`$l=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$logB64'));" +
        "try{Start-Transcript -LiteralPath `$l -Force | Out-Null}catch{};" +
        "`$t=[Text.Encoding]::UTF8.GetString(`$b).TrimStart([char]0xFEFF);" +
        "try{`$sb=[ScriptBlock]::Create(`$t)}catch{Write-Host '  [!!] Модуль не запустился: файл выпуска повреждён. Запустите установщик заново. / The module could not start: run the installer again.' -ForegroundColor Red;[void](Read-Host 'Enter');exit 8};" +
        "& `$sb $argLine;" +
        "try{Stop-Transcript | Out-Null}catch{}"
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($boot))
    $exit = $null
    try {
        $p = Start-Process (Get-HostExe) -Verb RunAs -Wait -PassThru -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $enc)
        $exit = $p.ExitCode
    }
    finally {
        Remove-Item -LiteralPath $scriptPath -Force -ErrorAction SilentlyContinue
        $script:LastElevatedLog = @(Read-ElevatedLog $logPath)
        Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue
    }
    return $exit
}

function Get-Title($Setting) {
    $t = $Setting.title.$($script:Lang)
    if (-not $t) { $t = $Setting.title.en }
    return $t
}

function Show-NumberedList($Settings) {
    $rows = @(); $applied = 0; $n = 0; $hasOptional = $false
    foreach ($s in $Settings) {
        $n++
        $on = [bool](Test-Applied $s)
        if ($on) { $applied++ }
        $tag = ''
        if ($s.optional) { $tag = ' ' + $script:S.OptionalTag; $hasOptional = $true }
        $mark = if ($on) { '[+]' } else { '[ ]' }
        $cell = ('[{0,2}] {1} {2}' -f $n, $mark, ((Get-Title $s) + $tag))
        $rows += [pscustomobject]@{ Cell = $cell; On = $on }
    }

    $colW = 0
    foreach ($r in $rows) { if ($r.Cell.Length -gt $colW) { $colW = $r.Cell.Length } }

    $width = 80
    try { if ($Host.UI.RawUI.WindowSize.Width -gt 0) { $width = [int]$Host.UI.RawUI.WindowSize.Width } } catch { }
    $gutter = 3
    $twoCols = (@($rows).Count -ge 4) -and ((2 + $colW + $gutter + $colW + 1) -le $width)

    if ($twoCols) {
        $half = [Math]::Ceiling(@($rows).Count / 2)
        for ($i = 0; $i -lt $half; $i++) {
            $L = $rows[$i]
            $padded = '  ' + $L.Cell.PadRight($colW)
            if ($L.On) { Write-Host $padded -NoNewline -ForegroundColor Green } else { Write-Host $padded -NoNewline }
            $j = $i + $half
            if ($j -lt @($rows).Count) {
                $R = $rows[$j]
                Write-Host (' ' * $gutter) -NoNewline
                if ($R.On) { Write-Host $R.Cell -ForegroundColor Green } else { Write-Host $R.Cell }
            }
            else { Write-Host '' }
        }
    }
    else {
        foreach ($r in $rows) {
            if ($r.On) { Write-Host ('  ' + $r.Cell) -ForegroundColor Green } else { Write-Host ('  ' + $r.Cell) }
        }
    }

    Write-Host ''
    Write-Host ("  " + ($script:S.AppliedCount -f $applied, @($Settings).Count)) -ForegroundColor DarkGray
    if ($hasOptional) {
        Write-Host ("  " + $script:S.OptionalNote) -ForegroundColor DarkGray
    }
}

function Apply-Selection($Settings, $Selected, $SnapId) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $all = Split-ByHive $Settings
    $sel = Split-ByHive $Selected
    $total = @($Selected).Count
    $done = 0
    Write-Host ''

    if (@($all.User).Count -gt 0) {
        try {
            $userSnap = Save-UserSnapshot @($all.User) $SnapId $stamp
            if ($userSnap) {
                Write-Host ("  " + $script:S.SnapSaved) -ForegroundColor DarkGray
            }
        }
        catch { Write-Host ("  " + $script:S.Oops + " " + (Get-ShortError $_)) -ForegroundColor Red }
    }
    foreach ($s in @($sel.User)) {
        try {
            Set-One $s
            Write-Host ("  " + $script:S.Applied + ": " + (Get-Title $s)) -ForegroundColor Green
            $done++
        }
        catch { Write-Host ("  " + $script:S.Failed + ": " + (Get-Title $s) + " - " + (Get-ShortError $_)) -ForegroundColor Red }
    }

    if (@($sel.Machine).Count -gt 0) {
        Write-Host ''
        Write-Host ("  " + $script:S.ElevateApply) -ForegroundColor Cyan
        try {
            $h = Invoke-HklmHelper 'Apply' @($all.Machine) @($sel.Machine) $SnapId $stamp
            if ($h.Result -and $h.Result.ok) {
                $done += [int]$h.Result.applied
                if ([int]$h.Result.failed -gt 0) {
                    Write-Host ("  " + ($script:S.HklmFailed -f [int]$h.Result.failed)) -ForegroundColor Red
                }
            }
            elseif ($h.Result -and $h.Result.error) {
                Write-Host ("  " + $h.Result.error) -ForegroundColor Red
            }
            else { Write-Host ("  " + $script:S.ElevateDeclined) -ForegroundColor Yellow }
        }
        catch { Write-Host ("  " + $script:S.ElevateDeclined) -ForegroundColor Yellow }
    }

    Write-Host ''
    Write-Host ("  " + ($script:S.ApplyDone -f $done, $total))
}

function Invoke-Revert($Settings, $SnapId) {
    $all = Split-ByHive $Settings
    $shown = $false
    Write-Host ''

    if (@($all.User).Count -gt 0) {
        $path = Get-LatestUserSnapshot $SnapId
        if ($path) {
            $shown = $true
            $doc = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
            Write-Host ("  " + ($script:S.Restoring -f $doc.taken)) -ForegroundColor Cyan
            $done = 0; $skipped = 0
            foreach ($e in $doc.entries) {
                $match = @($all.User) | Where-Object { $_.path -eq $e.Path -and $_.name -eq $e.Name }
                if (-not $match) { $skipped++; continue }
                try { Restore-One $e; $done++ }
                catch { Write-Host ("  " + $script:S.Failed + ": " + $e.Name + " - " + (Get-ShortError $_)) -ForegroundColor Red }
            }
            Write-Host ("  " + ($script:S.RestoreDone -f $done, $skipped))
        }
    }

    if (@($all.Machine).Count -gt 0) {
        Write-Host ''
        Write-Host ("  " + $script:S.ElevateRevert) -ForegroundColor Cyan
        try {
            $h = Invoke-HklmHelper 'Revert' @($all.Machine) @() $SnapId ''
            if ($h.Result -and $h.Result.ok) {
                $shown = $true
                Write-Host ("  " + ($script:S.RestoreDone -f [int]$h.Result.reverted, [int]$h.Result.skipped))
            }
            elseif ($h.Result -and $h.Result.error) {
                Write-Host ("  " + $h.Result.error) -ForegroundColor Red
            }
            else { Write-Host ("  " + $script:S.ElevateDeclined) -ForegroundColor Yellow }
        }
        catch { Write-Host ("  " + $script:S.ElevateDeclined) -ForegroundColor Yellow }
    }

    if (-not $shown) {
        Write-Host ("  " + $script:S.NoSnapshot) -ForegroundColor Yellow
    }
}

function Invoke-CategoryScreen($CategoryTitle, $Settings, $SnapId) {
    while ($true) {
        Write-Host ''
        Write-Host "  $CategoryTitle" -ForegroundColor Cyan
        Write-Host ''
        Show-NumberedList $Settings
        Write-Host ''
        Write-Host ("  " + $script:S.PickHint)
        Write-Host ("  " + $script:S.PickActions)
        Write-Host ''
        $answer = (Read-Host ("  " + $script:S.Choice)).Trim()

        if ($answer -eq '0' -or $answer -eq '') { return }
        if ($answer -eq 'r' -or $answer -eq 'R') { Invoke-Revert $Settings $SnapId; Pause-Return; continue }
        if ($answer -eq 'a' -or $answer -eq 'A') {
            $auto = @($Settings | Where-Object { -not $_.optional })
            Apply-Selection $Settings $auto $SnapId; Pause-Return; continue
        }

        $tokens = $answer -split '[,\s]+' | Where-Object { $_ -ne '' }
        $selected = @(); $bad = $false
        foreach ($tok in $tokens) {
            $num = 0
            if ([int]::TryParse($tok, [ref]$num) -and $num -ge 1 -and $num -le $Settings.Count) {
                $selected += $Settings[$num - 1]
            }
            else { $bad = $true }
        }
        if ($bad -or $selected.Count -eq 0) {
            Write-Host ''
            Write-Host ("  " + $script:S.BadChoice) -ForegroundColor Yellow
            Pause-Return
            continue
        }
        Apply-Selection $Settings $selected $SnapId
        Pause-Return
    }
}

function Pause-Return {
    Write-Host ''
    [void](Read-Host ("  " + $script:S.PressEnter))
}

function Get-PresetCategoryOrder($Settings) {
    $seen = @{}; $order = @()
    foreach ($s in @($Settings)) {
        $c = "$($s.category)"
        if ($c -and -not $seen.ContainsKey($c)) { $seen[$c] = $true; $order += $c }
    }
    return $order
}

function Apply-PresetSelection($Settings, $Selected) {
    foreach ($catId in (Get-PresetCategoryOrder $Selected)) {
        $catAll = @($Settings | Where-Object { $_.category -eq $catId })
        $catSel = @($Selected | Where-Object { $_.category -eq $catId })
        if (@($catSel).Count -gt 0) { Apply-Selection $catAll $catSel $catId }
    }
}

function Invoke-PresetRevert($Settings) {
    foreach ($catId in (Get-PresetCategoryOrder $Settings)) {
        $catAll = @($Settings | Where-Object { $_.category -eq $catId })
        Invoke-Revert $catAll $catId
    }
}

function Invoke-PresetScreen($Title, $Desc, $Settings) {
    while ($true) {
        Write-Host ''
        Write-Host "  $Title" -ForegroundColor Cyan
        if ($Desc) { Write-Host "  $Desc" -ForegroundColor DarkGray }
        Write-Host ''
        Show-NumberedList $Settings
        Write-Host ''
        Write-Host ("  " + $script:S.PickHint)
        Write-Host ("  " + $script:S.PickActions)
        Write-Host ''
        $answer = (Read-Host ("  " + $script:S.Choice)).Trim()

        if ($answer -eq '0' -or $answer -eq '') { return }
        if ($answer -eq 'r' -or $answer -eq 'R') { Invoke-PresetRevert $Settings; Pause-Return; continue }
        if ($answer -eq 'a' -or $answer -eq 'A') {
            $auto = @($Settings | Where-Object { -not $_.optional })
            Apply-PresetSelection $Settings $auto; Pause-Return; continue
        }

        $tokens = $answer -split '[,\s]+' | Where-Object { $_ -ne '' }
        $selected = @(); $bad = $false
        foreach ($tok in $tokens) {
            $num = 0
            if ([int]::TryParse($tok, [ref]$num) -and $num -ge 1 -and $num -le $Settings.Count) {
                $selected += $Settings[$num - 1]
            }
            else { $bad = $true }
        }
        if ($bad -or $selected.Count -eq 0) {
            Write-Host ''
            Write-Host ("  " + $script:S.BadChoice) -ForegroundColor Yellow
            Pause-Return
            continue
        }
        Apply-PresetSelection $Settings $selected
        Pause-Return
    }
}
