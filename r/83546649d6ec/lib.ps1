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

$script:KeyPairs = @{ 'ф' = 'a'; 'к' = 'r'; 'г' = 'u'; 'ч' = 'x'; 'в' = 'd'; 'ц' = 'w'; 'о' = 'j'; 'д' = 'l' }
function Get-Key([string]$Answer) {
    $a = "$Answer".Trim().ToLower()
    if ($a.Length -ne 1) { return '' }
    if ($script:KeyPairs.ContainsKey($a)) { return $script:KeyPairs[$a] }
    return $a
}

function Get-ShortError($Err) {
    $m = "$($Err.Exception.Message)" -split "`r?`n" | Select-Object -First 1
    if ($m.Length -gt 160) { $m = $m.Substring(0, 160) + '...' }
    return $m
}

function Invoke-Quiet($Exe, $Arguments) {
    $app = $null
    if ($script:LiveShown) { $app = Get-Command $Exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if ($app) { return (Invoke-Watched $app.Path $Arguments) }
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $Exe @Arguments 2>&1 | Out-Null; return $LASTEXITCODE }
    catch { return 1 }
    finally { $ErrorActionPreference = $old }
}

function ConvertTo-ArgLine($Arguments) {
    $parts = foreach ($a in @($Arguments)) {
        $t = [string]$a
        if ($t -eq '') { '""' }
        elseif ($t -notmatch '[\s"]') { $t }
        else { '"' + (($t -replace '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"' }
    }
    return ($parts -join ' ')
}

function Get-FileTail([string]$Path) {
    try {
        $fs = New-Object IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        try {
            $n = [int][Math]::Min($fs.Length, 4096)
            if ($n -le 0) { return '' }
            [void]$fs.Seek(-$n, [IO.SeekOrigin]::End)
            $b = New-Object byte[] $n
            [void]$fs.Read($b, 0, $n)
            return [Text.Encoding]::UTF8.GetString($b)
        } finally { $fs.Dispose() }
    } catch { return '' }
}

function Get-ProgressHint([string]$Text) {
    $m = [regex]::Matches($Text, '([\d.,]+)\s*([KMGКМГ]i?[BБ])\s*/\s*([\d.,]+\s*[KMGКМГ]i?[BБ])')
    if ($m.Count -gt 0) { $l = $m[$m.Count - 1]; return ('{0} / {1}' -f $l.Groups[1].Value, $l.Groups[3].Value) }
    $m = [regex]::Matches($Text, '(\d{1,3})\s*%')
    if ($m.Count -gt 0) { return ($m[$m.Count - 1].Groups[1].Value + '%') }
    return ''
}

function Invoke-Watched([string]$Path, $Arguments) {
    $out = [IO.Path]::GetTempFileName()
    $err = [IO.Path]::GetTempFileName()
    try {
        $p = Start-Process -FilePath $Path -ArgumentList (ConvertTo-ArgLine $Arguments) -NoNewWindow -PassThru `
            -RedirectStandardOutput $out -RedirectStandardError $err
        $null = $p.Handle
        $spin = @('|', '/', '-', '\')
        if ($script:Ui -and $script:Ui.Box) { $spin = @('◐', '◓', '◑', '◒') }
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $i = 0
        $hint = ''
        while (-not $p.HasExited) {
            if ($i % 8 -eq 0) { $h = Get-ProgressHint (Get-FileTail $out); if ($h) { $hint = $h } }
            $sec = [int]$clock.Elapsed.TotalSeconds
            $tail = '{0} {1}:{2:00}' -f $spin[$i % $spin.Count], [int][Math]::Floor($sec / 60), ($sec % 60)
            if ($hint) { $tail += ' · ' + $hint }
            if ($sec -ge 40) { $tail += ' · ' + $script:S.LiveLong }
            Write-LiveTail $tail
            $i++
            Start-Sleep -Milliseconds 250
        }
        $p.WaitForExit()
        Write-LiveTail ''
        return $p.ExitCode
    } catch { return 1 }
    finally { Remove-Item -LiteralPath $out, $err -Force -ErrorAction SilentlyContinue }
}

function Get-ArchName($Code) {
    switch ([string]$Code) {
        { $_ -in @('34404', 'AMD64', '9') } { return 'x64' }
        { $_ -in @('43620', 'ARM64', '12') } { return 'arm64' }
        { $_ -in @('332', 'x86', '0') } { return 'x86' }
    }
    return ''
}

function Get-ArchProfile {
    $arch = ''
    $source = ''
    try {
        if (-not ('AutoSettings.Wow' -as [type])) {
            Add-Type -Namespace AutoSettings -Name Wow -ErrorAction Stop -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool IsWow64Process2(IntPtr process, out ushort processMachine, out ushort nativeMachine);
[DllImport("kernel32.dll")]
public static extern IntPtr GetCurrentProcess();
'@
        }
        $processMachine = [uint16]0
        $nativeMachine = [uint16]0
        if ([AutoSettings.Wow]::IsWow64Process2([AutoSettings.Wow]::GetCurrentProcess(), [ref]$processMachine, [ref]$nativeMachine)) {
            $arch = Get-ArchName $nativeMachine
            if ($arch) { $source = 'api' }
        }
    }
    catch {
        for ($e = $_.Exception; $e; $e = $e.InnerException) {
            if ($e -is [EntryPointNotFoundException]) {
                $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
                $source = 'bitness'
            }
        }
    }
    if (-not $arch) {
        try {
            $key = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -Name PROCESSOR_ARCHITECTURE -ErrorAction Stop
            $arch = Get-ArchName $key.PROCESSOR_ARCHITECTURE
            if ($arch) { $source = 'registry' }
        } catch {}
    }
    if (-not $arch) {
        try {
            $cpu = @(Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop)[0]
            $arch = Get-ArchName $cpu.Architecture
            if ($arch) { $source = 'cim' }
        } catch {}
    }
    return [pscustomobject]@{ Arch = $arch; Source = $source }
}

function Select-Payload($Manifest, [string]$Name) {
    $found = @($Manifest.payloads | Where-Object { $_.name -eq $Name -and $_.arch -eq $script:Arch })
    if ($found.Count -ne 1) { return $null }
    return $found[0]
}

function Get-PeMachine([string]$Path) {
    $head = New-Object byte[] 4096
    $stream = [IO.File]::OpenRead($Path)
    try { $read = $stream.Read($head, 0, $head.Length) } finally { $stream.Dispose() }
    if ($read -lt 64 -or $head[0] -ne 0x4D -or $head[1] -ne 0x5A) { return '' }
    $offset = [BitConverter]::ToInt32($head, 0x3C)
    if ($offset -lt 0 -or $offset + 6 -gt $read) { return '' }
    if ($head[$offset] -ne 0x50 -or $head[$offset + 1] -ne 0x45 -or $head[$offset + 2] -ne 0 -or $head[$offset + 3] -ne 0) { return '' }
    return (Get-ArchName ([BitConverter]::ToUInt16($head, $offset + 4)))
}

function Get-HostExe {
    $wow = [Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess
    $system = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if ($wow) {
        $sysnative = Join-Path $env:SystemRoot 'Sysnative\WindowsPowerShell\v1.0\powershell.exe'
        if (Test-Path -LiteralPath $sysnative) { $system = $sysnative }
    }
    try {
        $path = (Get-Process -Id $PID -ErrorAction Stop).Path
        if ($path -and (Test-Path -LiteralPath $path)) {
            $full = [IO.Path]::GetFullPath($path)
            $inAdminDir = $false
            foreach ($dir in @($env:ProgramFiles, $env:SystemRoot)) {
                if ($dir -and $full.StartsWith(($dir.TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) { $inAdminDir = $true }
            }
            foreach ($dir in @((Join-Path $env:SystemRoot 'SysWOW64'), ${env:ProgramFiles(x86)})) {
                if ($dir -and $full.StartsWith(($dir.TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) { $inAdminDir = $false }
            }
            if ($wow) { $inAdminDir = $false }
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
        if ($t -match '\.\.\.\s*$') { continue }
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
    Start-Work
    Write-Live $script:S.LiveUac
    try {
        $p = Start-Process (Get-HostExe) -Verb RunAs -Wait -PassThru -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $enc)
        $exit = $p.ExitCode
    }
    finally {
        Clear-Live
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

function Start-Work {
    $jokes = @($script:S.Magic)
    $script:WorkJoke = "$($jokes[(Get-Random -Maximum $jokes.Count)])"
    $script:Outcome = @()
    $script:LiveShown = $false
    Write-Host ''
}

function Get-LiveWidth {
    $w = 80
    try { if ($Host.UI.RawUI.WindowSize.Width -gt 0) { $w = [int]$Host.UI.RawUI.WindowSize.Width } } catch { }
    return ($w - 1)
}

function Write-Live([string]$What) {
    $script:LiveWhat = $What
    Write-LiveTail ''
}

function Write-LiveTail([string]$Tail) {
    $text = '  ' + $script:WorkJoke
    if ($script:LiveWhat) { $text += ': ' + $script:LiveWhat }
    $text += '...'
    if ($Tail) { $text += ' ' + $Tail }
    $w = Get-LiveWidth
    if ($text.Length -gt $w) { $text = $text.Substring(0, $w) }
    Write-Host ("`r" + $text.PadRight($w)) -NoNewline -ForegroundColor Cyan
    $script:LiveShown = $true
}

function Clear-Live {
    if ($script:LiveShown) { Write-Host ("`r" + (' ' * (Get-LiveWidth)) + "`r") -NoNewline }
    $script:LiveShown = $false
}

function Add-Outcome([string]$Kind, [string]$Text) {
    $script:Outcome += @{ Kind = $Kind; Text = $Text }
}

function Show-Outcome {
    Clear-Live
    Write-Host ('  ' + $script:S.ResultTitle) -ForegroundColor Cyan
    $lines = @($script:Outcome)
    if ($lines.Count -eq 0) { Write-Host ('    ' + $script:S.ResultEmpty) -ForegroundColor DarkGray }
    foreach ($l in $lines) {
        switch ($l.Kind) {
            'ok'   { Write-Host ('    [OK] ' + $l.Text) -ForegroundColor Green }
            'warn' { Write-Host ('    [!]  ' + $l.Text) -ForegroundColor Yellow }
            'fail' { Write-Host ('    [!!] ' + $l.Text) -ForegroundColor Red }
            default { Write-Host ('    ' + $l.Text) -ForegroundColor DarkGray }
        }
    }
    $script:Outcome = @()
}

function Invoke-ApplyCore($Settings, $Selected, $SnapId) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $all = Split-ByHive $Settings
    $sel = Split-ByHive $Selected
    $r = @{ Done = 0; Total = @($Selected).Count; Failed = @(); Declined = 0; Snap = $false }

    $userOk = $true
    if (@($all.User).Count -gt 0) {
        try { if (Save-UserSnapshot @($all.User) $SnapId $stamp) { $r.Snap = $true } }
        catch {
            $userOk = $false
            $r.Failed += ($script:S.OutNoSnap + ' - ' + (Get-ShortError $_))
        }
    }
    if ($userOk) {
        foreach ($s in @($sel.User)) {
            try { Set-One $s; $r.Done++ }
            catch { $r.Failed += ((Get-Title $s) + ' - ' + (Get-ShortError $_)) }
        }
    }

    if (@($sel.Machine).Count -gt 0) {
        Write-Live $script:S.LiveUac
        try {
            $h = Invoke-HklmHelper 'Apply' @($all.Machine) @($sel.Machine) $SnapId $stamp
            if ($h.Result -and $h.Result.ok) {
                $r.Done += [int]$h.Result.applied
                $r.Snap = $true
                if ([int]$h.Result.failed -gt 0) { $r.Failed += ($script:S.HklmFailed -f [int]$h.Result.failed) }
            }
            elseif ($h.Result -and $h.Result.error) { $r.Failed += "$($h.Result.error)" }
            else { $r.Declined += @($sel.Machine).Count }
        }
        catch { $r.Declined += @($sel.Machine).Count }
    }
    return $r
}

function Add-ApplyOutcome($R) {
    $kind = 'ok'
    if ($R.Done -lt $R.Total) { $kind = 'warn' }
    if ($R.Done -eq 0 -and $R.Total -gt 0) { $kind = 'fail' }
    Add-Outcome $kind ($script:S.ApplyDone -f $R.Done, $R.Total)
    $shown = 0
    foreach ($f in @($R.Failed)) {
        if ($shown -ge 5) { break }
        Add-Outcome 'fail' ($script:S.OutFailed -f $f); $shown++
    }
    if (@($R.Failed).Count -gt $shown) { Add-Outcome 'fail' ($script:S.OutMore -f (@($R.Failed).Count - $shown)) }
    if ($R.Declined -gt 0) { Add-Outcome 'warn' ($script:S.OutDeclined -f $R.Declined) }
    if ($R.Snap) { Add-Outcome 'note' $script:S.SnapSaved }
}

function Apply-Selection($Settings, $Selected, $SnapId) {
    Start-Work
    Write-Live ''
    $r = Invoke-ApplyCore $Settings $Selected $SnapId
    Add-ApplyOutcome $r
    Show-Outcome
}

function Invoke-RevertCore($Settings, $SnapId) {
    $all = Split-ByHive $Settings
    $r = @{ Restored = 0; Skipped = 0; Had = $false; Failed = @(); Declined = $false }

    if (@($all.User).Count -gt 0) {
        $path = Get-LatestUserSnapshot $SnapId
        if ($path) {
            $r.Had = $true
            $doc = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
            foreach ($e in $doc.entries) {
                $match = @($all.User) | Where-Object { $_.path -eq $e.Path -and $_.name -eq $e.Name }
                if (-not $match) { $r.Skipped++; continue }
                try { Restore-One $e; $r.Restored++ }
                catch { $r.Failed += ("$($e.Name)" + ' - ' + (Get-ShortError $_)) }
            }
        }
    }

    if (@($all.Machine).Count -gt 0) {
        Write-Live $script:S.LiveUac
        try {
            $h = Invoke-HklmHelper 'Revert' @($all.Machine) @() $SnapId ''
            if ($h.Result -and $h.Result.ok) {
                $r.Had = $true
                $r.Restored += [int]$h.Result.reverted
                $r.Skipped += [int]$h.Result.skipped
            }
            elseif ($h.Result -and $h.Result.error) { $r.Failed += "$($h.Result.error)" }
            else { $r.Declined = $true }
        }
        catch { $r.Declined = $true }
    }
    return $r
}

function Add-RevertOutcome($R) {
    if ($R.Had) { Add-Outcome 'ok' ($script:S.OutRestored -f $R.Restored) }
    foreach ($f in @($R.Failed)) { Add-Outcome 'fail' ($script:S.OutFailed -f $f) }
    if ($R.Declined) { Add-Outcome 'warn' $script:S.OutRevertDeclined }
    if (-not $R.Had -and -not $R.Declined -and @($R.Failed).Count -eq 0) { Add-Outcome 'warn' $script:S.NoSnapshot }
}

function Invoke-Revert($Settings, $SnapId) {
    Start-Work
    Write-Live ''
    $r = Invoke-RevertCore $Settings $SnapId
    Add-RevertOutcome $r
    Show-Outcome
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
        $key = Get-Key $answer
        if ($key -eq 'r') { Invoke-Revert $Settings $SnapId; Pause-Return; continue }
        if ($key -eq 'a') {
            $auto = @($Settings | Where-Object { -not $_.optional })
            if ($auto.Count -eq 0) {
                Write-Host ''
                Write-Host ("  " + $script:S.AllOptional) -ForegroundColor Yellow
                Pause-Return; continue
            }
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
    Start-Work
    Write-Live ''
    $sum = @{ Done = 0; Total = 0; Failed = @(); Declined = 0; Snap = $false }
    foreach ($catId in (Get-PresetCategoryOrder $Selected)) {
        $catAll = @($Settings | Where-Object { $_.category -eq $catId })
        $catSel = @($Selected | Where-Object { $_.category -eq $catId })
        if (@($catSel).Count -eq 0) { continue }
        $r = Invoke-ApplyCore $catAll $catSel $catId
        $sum.Done += $r.Done; $sum.Total += $r.Total; $sum.Declined += $r.Declined
        $sum.Failed += @($r.Failed)
        if ($r.Snap) { $sum.Snap = $true }
    }
    Add-ApplyOutcome $sum
    Show-Outcome
}

function Invoke-PresetRevert($Settings) {
    Start-Work
    Write-Live ''
    $sum = @{ Restored = 0; Skipped = 0; Had = $false; Failed = @(); Declined = $false }
    foreach ($catId in (Get-PresetCategoryOrder $Settings)) {
        $catAll = @($Settings | Where-Object { $_.category -eq $catId })
        $r = Invoke-RevertCore $catAll $catId
        $sum.Restored += $r.Restored; $sum.Skipped += $r.Skipped
        $sum.Failed += @($r.Failed)
        if ($r.Had) { $sum.Had = $true }
        if ($r.Declined) { $sum.Declined = $true }
    }
    Add-RevertOutcome $sum
    Show-Outcome
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
        $key = Get-Key $answer
        if ($key -eq 'r') { Invoke-PresetRevert $Settings; Pause-Return; continue }
        if ($key -eq 'a') {
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
