$script:SnapshotBase = Join-Path $env:ProgramData 'AutoSettings.win'
$script:SnapshotRoot = Join-Path $script:SnapshotBase 'snapshots'
$script:UserCopyBase = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'AutoSettings.win'
$script:UserCopyRoot = Join-Path $script:UserCopyBase 'backups'
$script:RunLogRoot = Join-Path $script:UserCopyBase 'logs'
$script:PrivateCopyBase = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'AutoSettings.win'
$script:PrivateCopyRoot = Join-Path $script:PrivateCopyBase 'backups'
$script:AllowedTypes = @('DWord', 'String', 'ExpandString', 'QWord', 'MultiString', 'Binary')

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

function Get-UserCopyDir { return (Get-SafeCopyDir $script:UserCopyBase $script:UserCopyRoot) }
function Get-PrivateCopyDir { return (Get-SafeCopyDir $script:PrivateCopyBase $script:PrivateCopyRoot) }

function Get-SafeCopyDir($Base, $Root) {
    foreach ($dir in @($Base, $Root)) {
        if (Test-Path -LiteralPath $dir) {
            if (-not (Test-NoReparse $dir)) { throw "user copy path is a reparse point: $dir" }
        }
        else {
            [void](New-Item -ItemType Directory -Path $dir -ErrorAction Stop)
        }
    }
    return $Root
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

function Get-PsName($Name) { if ("$Name" -eq '') { return '(default)' } return "$Name" }

function Send-EnvChange($Path, $Name) {
    $target = $null
    if ("$Path" -match '^HKCU:\\Environment$') { $target = 'User' }
    elseif ("$Path" -match '^HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment$') { $target = 'Machine' }
    if (-not $target) { return }
    try { [Environment]::SetEnvironmentVariable("$Name", [Environment]::GetEnvironmentVariable("$Name", $target), $target) } catch {}
}

function Get-FlagsTarget($Setting, $State) {
    $old = [long]0
    if ($State.ValueExists) { $old = [long]"$($State.Data)" }
    return (($old -band (-bnot [long]$Setting.value.clear)) -bor [long]$Setting.value.set)
}

function Get-CurrentState($Setting) {
    $state = @{ KeyExists = $false; ValueExists = $false; Data = $null; Kind = $null }
    if (Test-Path -LiteralPath $Setting.path) {
        $state.KeyExists = $true
        $psName = Get-PsName $Setting.name
        $item = Get-ItemProperty -LiteralPath $Setting.path -Name $psName -ErrorAction SilentlyContinue
        if ($null -ne $item) {
            $prop = $item.PSObject.Properties[$psName]
            if ($null -ne $prop) {
                $state.ValueExists = $true
                $state.Data = $prop.Value
                try { $state.Kind = "$((Get-Item -LiteralPath $Setting.path).GetValueKind("$($Setting.name)"))" } catch {}
            }
        }
    }
    return $state
}

function Test-Applied($Setting) {
    $state = Get-CurrentState $Setting
    if ($Setting.type -eq 'Remove') { return (-not $state.ValueExists) }
    if (-not $state.ValueExists) { return $false }
    if ($Setting.type -eq 'Flags') {
        $mask = [long]$Setting.value.set -bor [long]$Setting.value.clear
        return ((([long]"$($state.Data)") -band $mask) -eq [long]$Setting.value.set)
    }
    if ($Setting.type -eq 'DWord') {
        $low = [long]4294967295
        try { return ((([long]"$($state.Data)") -band $low) -eq (([long]"$($Setting.value)") -band $low)) } catch { return $false }
    }
    return ("$($state.Data)" -eq "$($Setting.value)")
}

function Set-One($Setting) {
    $psName = Get-PsName $Setting.name
    if ($Setting.type -eq 'Remove') {
        if (Test-Path -LiteralPath $Setting.path) {
            Remove-ItemProperty -LiteralPath $Setting.path -Name $psName -ErrorAction SilentlyContinue
        }
        if (-not (Test-Applied $Setting)) { throw $script:S.ReadBack }
        Send-EnvChange $Setting.path $Setting.name
        return
    }
    $type = $Setting.type
    $value = $Setting.value
    if ($type -eq 'Flags') {
        $state = Get-CurrentState $Setting
        $value = Get-FlagsTarget $Setting $state
        $type = 'String'
        if ($state.ValueExists -and $state.Kind) { $type = $state.Kind }
        if ($type -eq 'String') { $value = "$value" }
    }
    if (-not (Test-Path -LiteralPath $Setting.path)) {
        [void](New-Item -Path $Setting.path -Force)
    }
    [void](New-ItemProperty -LiteralPath $Setting.path -Name $psName `
        -PropertyType $type -Value $value -Force)
    if (-not (Test-Applied $Setting)) { throw $script:S.ReadBack }
    Send-EnvChange $Setting.path $Setting.name
}

function Restore-One($Entry) {
    if ($Entry.ValueExists) {
        if ($script:AllowedTypes -notcontains "$($Entry.Type)") {
            Write-Host ("  " + ($script:S.SkipType -f $Entry.Type, $Entry.Path, $Entry.Name)) -ForegroundColor Yellow
            return
        }
        if (-not (Test-Path -LiteralPath $Entry.Path)) { [void](New-Item -Path $Entry.Path -Force) }
        $data = $Entry.Data
        if ("$($Entry.Type)" -eq 'Binary') { $data = [byte[]]@($data) }
        elseif ("$($Entry.Type)" -eq 'MultiString') { $data = [string[]]@($data) }
        [void](New-ItemProperty -LiteralPath $Entry.Path -Name (Get-PsName $Entry.Name) `
            -PropertyType $Entry.Type -Value $data -Force)
        Send-EnvChange $Entry.Path $Entry.Name
        return
    }
    if (Test-Path -LiteralPath $Entry.Path) {
        Remove-ItemProperty -LiteralPath $Entry.Path -Name (Get-PsName $Entry.Name) -ErrorAction SilentlyContinue
        Send-EnvChange $Entry.Path $Entry.Name
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
        $type = $s.type
        if ($cur.ValueExists -and $cur.Kind) { $type = $cur.Kind }
        $entries += @{
            Path = $s.path; Name = $s.name; Type = $type
            KeyExists = $cur.KeyExists; ValueExists = $cur.ValueExists; Data = $cur.Data
        }
    }
    return $entries
}

function Merge-SnapshotEntries($Fresh, $Settings, $PrevPath) {
    if (-not $PrevPath) { return @($Fresh) }
    try { $prev = @(([IO.File]::ReadAllText($PrevPath, [Text.Encoding]::UTF8) | ConvertFrom-Json).entries) }
    catch { return @($Fresh) }
    $byKey = @{}
    foreach ($e in $prev) { if ($null -ne $e) { $byKey["$($e.Path)|$($e.Name)".ToLowerInvariant()] = $e } }
    $out = @(); $seen = @{}
    foreach ($f in @($Fresh)) {
        $k = "$($f.Path)|$($f.Name)".ToLowerInvariant()
        $seen[$k] = $true
        $s = @($Settings) | Where-Object { "$($_.path)|$($_.name)".ToLowerInvariant() -eq $k } | Select-Object -First 1
        if ($byKey.ContainsKey($k) -and $null -ne $s -and (Test-Applied $s)) {
            $o = $byKey[$k]
            $out += @{ Path = $o.Path; Name = $o.Name; Type = $o.Type; KeyExists = [bool]$o.KeyExists; ValueExists = [bool]$o.ValueExists; Data = $o.Data }
        }
        else { $out += $f }
    }
    foreach ($k in $byKey.Keys) {
        if ($seen.ContainsKey($k)) { continue }
        $o = $byKey[$k]
        $out += @{ Path = $o.Path; Name = $o.Name; Type = $o.Type; KeyExists = [bool]$o.KeyExists; ValueExists = [bool]$o.ValueExists; Data = $o.Data }
    }
    return $out
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

function Get-TextHash([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))) -replace '-', '') }
    finally { $sha.Dispose() }
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
    $entries = Merge-SnapshotEntries (New-SnapshotEntries $UserSettings) $UserSettings (Get-LatestIn $dir $SnapId)
    return (Write-SnapshotFile $entries $SnapId $Stamp $dir)
}

function Save-MachineSnapshot($MachineSettings, $SnapId, $Stamp) {
    if (@($MachineSettings).Count -eq 0) { return $null }
    $dir = Get-SnapshotDir
    $entries = Merge-SnapshotEntries (New-SnapshotEntries $MachineSettings) $MachineSettings (Get-LatestIn $dir $SnapId)
    return (Write-SnapshotFile $entries $SnapId $Stamp $dir)
}

function Get-LatestUserSnapshot($SnapId)    { return (Get-LatestIn $script:UserCopyRoot $SnapId) }
function Get-LatestMachineSnapshot($SnapId) { return (Get-LatestIn $script:SnapshotRoot $SnapId) }
function Get-LatestSnapshot($SnapId)        { return (Get-LatestIn $script:UserCopyRoot $SnapId) }
function Get-LatestPrivateSnapshot($SnapId) {
    $p = Get-LatestIn $script:PrivateCopyRoot $SnapId
    if ($null -eq $p) { $p = Get-LatestIn $script:UserCopyRoot $SnapId }
    return $p
}

function Remove-SnapshotFiles($JsonPath) {
    $dir = Split-Path -Parent $JsonPath
    $base = [IO.Path]::GetFileNameWithoutExtension($JsonPath)
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "$base.json" -or $_.Name -like "$base.*.bak" })) {
        Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-HklmHelper($Mode, $SnapSet, $ApplySet, $SnapId, $Stamp, $Jobs) {
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
        SnapSet = @($SnapSet); ApplySet = @($ApplySet); ResultPath = $resultPath; Jobs = @($Jobs | Where-Object { $_ })
    } | ConvertTo-Json -Depth 8 -Compress
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

function Test-RebootPending {
    foreach ($key in @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')) {
        if (Test-Path -LiteralPath $key) { return $true }
    }
    try {
        $item = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction Stop
        if (@($item.PendingFileRenameOperations | Where-Object { $_ }).Count -gt 0) { return $true }
    } catch {}
    return $false
}

function Get-SystemFreeGb {
    try { return [math]::Round((New-Object IO.DriveInfo ($env:SystemDrive)).AvailableFreeSpace / 1GB, 1) }
    catch { return -1 }
}

function Get-SessionAccounts {
    $me = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $owners = @()
    try {
        $session = [Diagnostics.Process]::GetCurrentProcess().SessionId
        foreach ($p in @(Get-CimInstance -ClassName Win32_Process -Filter "Name='explorer.exe'" -ErrorAction Stop)) {
            if ($p.SessionId -ne $session) { continue }
            $o = Invoke-CimMethod -InputObject $p -MethodName GetOwner -ErrorAction Stop
            if ($o.User) { $owners += $(if ($o.Domain) { $o.Domain + '\' + $o.User } else { $o.User }) }
        }
    } catch {}
    return [pscustomobject]@{ Me = $me; Desktop = @($owners | Select-Object -Unique) }
}

$script:MinFreeGb = 2

function Get-PreflightIssues {
    $issues = @()
    if (Test-RebootPending) { $issues += [pscustomobject]@{ Kind = 'reboot'; Value = $null } }
    $free = Get-SystemFreeGb
    if ($free -ge 0 -and $free -lt $script:MinFreeGb) { $issues += [pscustomobject]@{ Kind = 'space'; Value = $free } }
    $acc = Get-SessionAccounts
    if ($acc.Me -and $acc.Desktop.Count -gt 0 -and -not ($acc.Desktop -contains $acc.Me)) {
        $issues += [pscustomobject]@{ Kind = 'account'; Value = @($acc.Me, $acc.Desktop[0]) }
    }
    return $issues
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

function Get-WindowsPowerShellExe {
    $exe = Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
    if (Test-Path -LiteralPath $exe) { return $exe }
    return $null
}

function Invoke-ElevatedFixed([string]$Code) {
    $ps = Get-WindowsPowerShellExe
    if (-not $ps) { return 1 }
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Code))
    try {
        $p = Start-Process -FilePath $ps -Verb RunAs -Wait -PassThru -WindowStyle Hidden -ArgumentList @(
            '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $enc)
        return $p.ExitCode
    }
    catch { return -1 }
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
        "`$__q=Split-Path `$l;`$__s=`$true;while(`$__q -and (Split-Path `$__q)){try{if((Get-Item -LiteralPath `$__q -Force).Attributes -band 1024){`$__s=`$false}}catch{`$__s=`$false};`$__q=Split-Path `$__q};" +
        "if(`$__s){try{Start-Transcript -LiteralPath `$l -Force | Out-Null}catch{}};" +
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
    $rows = @(); $applied = 0; $n = 0; $hasOptional = $false; $notes = @()
    foreach ($s in $Settings) {
        $n++
        $on = [bool](Test-Applied $s)
        if ($on) { $applied++ }
        $tag = ''
        if ($s.optional) { $tag = ' ' + $script:S.OptionalTag; $hasOptional = $true }
        if ($s.effect) { $tag += ' ' + $script:S.Effect["$($s.effect)"] }
        if ($s.warn) { $notes += ('[{0,2}] {1}' -f $n, "$($s.warn.$($script:Lang))") }
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
    foreach ($note in $notes) { Write-Host ("  " + $note) -ForegroundColor DarkYellow }
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

function Write-RunLog($Lines) {
    try {
        foreach ($dir in @($script:UserCopyBase, $script:RunLogRoot)) {
            if (Test-Path -LiteralPath $dir) { if (-not (Test-NoReparse $dir)) { return '' } }
            else { [void](New-Item -ItemType Directory -Path $dir -ErrorAction Stop) }
        }
        $path = Join-Path $script:RunLogRoot ((Get-Date).ToString('yyyy-MM-dd') + '.log')
        $text = ''
        if (-not $script:RunLogStarted) {
            $ps = $PSVersionTable.PSVersion
            $text += "`r`n=== " + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + ' | ' + "$product $build.$ubr" + ' | ' +
                "$script:Arch" + ' | ' + "$script:Lang" + ' | PowerShell ' + $ps.Major + '.' + $ps.Minor + " ===`r`n"
            $script:RunLogStarted = $true
        }
        $text += (Get-Date).ToString('HH:mm:ss') + ' ' + $script:LiveWhat + "`r`n"
        foreach ($l in @($Lines)) { $text += '    [' + $l.Kind + '] ' + $l.Text + "`r`n" }
        if ($env:USERPROFILE) { $text = $text.Replace($env:USERPROFILE, '%USERPROFILE%') }
        [IO.File]::AppendAllText($path, $text, (New-Object Text.UTF8Encoding $true))
        return $path
    }
    catch { return '' }
}

function Show-Outcome {
    Clear-Live
    Write-Host ('  ' + $script:S.ResultTitle) -ForegroundColor Cyan
    $lines = @($script:Outcome)
    $logPath = Write-RunLog $lines
    if ($lines.Count -eq 0) { Write-Host ('    ' + $script:S.ResultEmpty) -ForegroundColor DarkGray }
    foreach ($l in $lines) {
        switch ($l.Kind) {
            'ok'   { Write-Host ('    [OK] ' + $l.Text) -ForegroundColor Green }
            'warn' { Write-Host ('    [!]  ' + $l.Text) -ForegroundColor Yellow }
            'fail' { Write-Host ('    [!!] ' + $l.Text) -ForegroundColor Red }
            default { Write-Host ('    ' + $l.Text) -ForegroundColor DarkGray }
        }
    }
    if ($logPath -and @($lines | Where-Object { $_.Kind -eq 'fail' }).Count -gt 0) {
        Write-Host ('    ' + $script:S.LogWhere) -ForegroundColor DarkGray
    }
    $script:Outcome = @()
}

function Get-ChangedPath { return (Join-Path $script:UserCopyRoot 'changed.json') }

function Get-ChangedIds {
    try {
        $path = Get-ChangedPath
        if (-not (Test-Path -LiteralPath $path)) { return @() }
        return @(([IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json).ids | Where-Object { $_ })
    }
    catch { return @() }
}

function Save-ChangedIds($Ids) {
    try {
        [void](Get-UserCopyDir)
        $json = @{ ids = @($Ids | Sort-Object -Unique) } | ConvertTo-Json -Depth 3
        [IO.File]::WriteAllText((Get-ChangedPath), $json, (New-Object Text.UTF8Encoding $false))
    }
    catch {}
}

function Get-BuildMarkPath { return (Join-Path $script:UserCopyRoot 'build.json') }

function Update-BuildMark([int]$Build, [int]$Ubr) {
    $prev = $null
    try {
        $path = Get-BuildMarkPath
        if (Test-Path -LiteralPath $path) { $prev = [int](([IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json).build) }
    }
    catch {}
    try {
        [void](Get-UserCopyDir)
        $json = @{ build = $Build; ubr = $Ubr } | ConvertTo-Json
        [IO.File]::WriteAllText((Get-BuildMarkPath), $json, (New-Object Text.UTF8Encoding $false))
    }
    catch {}
    if ($prev -and $prev -ne $Build) { return $prev }
    return $null
}

function Add-ChangedIds($Ids) {
    $add = @($Ids | Where-Object { $_ })
    if ($add.Count -gt 0) { Save-ChangedIds (@(Get-ChangedIds) + $add) }
}

function Remove-ChangedIds($Ids) {
    $drop = @($Ids | Where-Object { $_ })
    if ($drop.Count -gt 0) { Save-ChangedIds @(Get-ChangedIds | Where-Object { $drop -notcontains $_ }) }
}

function Invoke-ApplyCore($Settings, $Selected, $SnapId, $Defer, $Stamp) {
    $stamp = if ($Stamp) { $Stamp } else { Get-Date -Format 'yyyyMMdd-HHmmss' }
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
        $okIds = @()
        foreach ($s in @($sel.User)) {
            try { Set-One $s; $r.Done++; $okIds += "$($s.id)" }
            catch { $r.Failed += ((Get-Title $s) + ' - ' + (Get-ShortError $_)) }
        }
        Add-ChangedIds $okIds
    }

    if (@($sel.Machine).Count -gt 0 -and $null -ne $Defer) {
        [void]$Defer.Add(@{ SnapId = $SnapId; SnapSet = @($all.Machine); ApplySet = @($sel.Machine) })
    }
    elseif (@($sel.Machine).Count -gt 0) {
        Write-Live $script:S.LiveUac
        try {
            $h = Invoke-HklmHelper 'Apply' @($all.Machine) @($sel.Machine) $SnapId $stamp
            Add-HelperApply $r $h @($sel.Machine)
        }
        catch { $r.Declined += @($sel.Machine).Count }
    }
    return $r
}

function Add-HelperApply($R, $H, $Machine) {
    if ($H.Result -and $H.Result.ok) {
        $R.Done += [int]$H.Result.applied
        $R.Snap = $true
        $named = 0
        $failedIds = @(@($H.Result.failures) | Where-Object { $_ } | ForEach-Object { "$($_.id)" })
        Add-ChangedIds @(@($Machine) | Where-Object { $failedIds -notcontains "$($_.id)" } | ForEach-Object { "$($_.id)" })
        foreach ($f in @($H.Result.failures)) {
            if ($null -eq $f) { continue }
            $s = @($Machine | Where-Object { "$($_.id)" -eq "$($f.id)" })
            if ($s.Count -eq 0) { continue }
            $why = if ("$($f.why)" -eq 'readback') { $script:S.ReadBack } else { "$($f.why)" }
            $R.Failed += ((Get-Title $s[0]) + ' - ' + $why); $named++
        }
        $rest = [int]$H.Result.failed - $named
        if ($rest -gt 0) { $R.Failed += ($script:S.HklmFailed -f $rest) }
    }
    elseif ($H.Result -and $H.Result.error) { $R.Failed += "$($H.Result.error)" }
    else { $R.Declined += @($Machine).Count }
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

function Invoke-RevertCore($Settings, $SnapId, $Defer) {
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
                try { Restore-One $e; $r.Restored++; Remove-ChangedIds @($match | ForEach-Object { "$($_.id)" }) }
                catch { $r.Failed += ("$($e.Name)" + ' - ' + (Get-ShortError $_)) }
            }
        }
    }

    if (@($all.Machine).Count -gt 0 -and $null -ne $Defer) {
        [void]$Defer.Add(@{ SnapId = $SnapId; SnapSet = @($all.Machine); ApplySet = @() })
    }
    elseif (@($all.Machine).Count -gt 0) {
        Write-Live $script:S.LiveUac
        try {
            Add-HelperRevert $r (Invoke-HklmHelper 'Revert' @($all.Machine) @() $SnapId '') @($all.Machine)
        }
        catch { $r.Declined = $true }
    }
    return $r
}

function Add-HelperRevert($R, $H, $Machine) {
    if ($H.Result -and $H.Result.ok) {
        $R.Had = $true
        Remove-ChangedIds @(@($Machine) | ForEach-Object { "$($_.id)" })
        $R.Restored += [int]$H.Result.reverted
        $R.Skipped += [int]$H.Result.skipped
    }
    elseif ($H.Result -and $H.Result.error) { $R.Failed += "$($H.Result.error)" }
    else { $R.Declined = $true }
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
    $jobs = New-Object System.Collections.ArrayList
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    foreach ($catId in (Get-PresetCategoryOrder $Selected)) {
        $catAll = @($Settings | Where-Object { $_.category -eq $catId })
        $catSel = @($Selected | Where-Object { $_.category -eq $catId })
        if (@($catSel).Count -eq 0) { continue }
        $r = Invoke-ApplyCore $catAll $catSel $catId $jobs $stamp
        $sum.Done += $r.Done; $sum.Total += $r.Total; $sum.Declined += $r.Declined
        $sum.Failed += @($r.Failed)
        if ($r.Snap) { $sum.Snap = $true }
    }
    if ($jobs.Count -gt 0) {
        $machine = @(foreach ($j in $jobs) { @($j.ApplySet) })
        Write-Live $script:S.LiveUac
        try { Add-HelperApply $sum (Invoke-HklmHelper 'Apply' @() @() '' $stamp @($jobs)) $machine }
        catch { $sum.Declined += $machine.Count }
    }
    Add-ApplyOutcome $sum
    Show-Outcome
}

function Invoke-PresetRevert($Settings) {
    Start-Work
    Write-Live ''
    $sum = @{ Restored = 0; Skipped = 0; Had = $false; Failed = @(); Declined = $false }
    $jobs = New-Object System.Collections.ArrayList
    foreach ($catId in (Get-PresetCategoryOrder $Settings)) {
        $catAll = @($Settings | Where-Object { $_.category -eq $catId })
        $r = Invoke-RevertCore $catAll $catId $jobs
        $sum.Restored += $r.Restored; $sum.Skipped += $r.Skipped
        $sum.Failed += @($r.Failed)
        if ($r.Had) { $sum.Had = $true }
        if ($r.Declined) { $sum.Declined = $true }
    }
    if ($jobs.Count -gt 0) {
        Write-Live $script:S.LiveUac
        $machine = @(foreach ($j in $jobs) { @($j.SnapSet) })
        try { Add-HelperRevert $sum (Invoke-HklmHelper 'Revert' @() @() '' '' @($jobs)) $machine }
        catch { $sum.Declined = $true }
    }
    Add-RevertOutcome $sum
    Show-Outcome
}

function Invoke-PresetModules($Modules) {
    foreach ($m in @($Modules)) {
        if ($null -eq $m) { continue }
        $t = $m.title.$($script:Lang); if (-not $t) { $t = $m.title.en }
        Write-Host ''
        if (Test-Yes (Read-Host ('  ' + ($script:S.PresetModuleAsk -f $t)))) { Invoke-Module "$($m.id)" }
    }
}

function Invoke-PresetScreen($Title, $Desc, $Settings, $Modules = @()) {
    while ($true) {
        Write-Host ''
        Write-Host "  $Title" -ForegroundColor Cyan
        if ($Desc) { Write-Host "  $Desc" -ForegroundColor DarkGray }
        Write-Host ''
        Show-NumberedList $Settings
        if (@($Modules).Count -gt 0) {
            Write-Host ''
            Write-Host ('  ' + $script:S.PresetModules) -ForegroundColor DarkGray
            foreach ($m in @($Modules)) {
                $t = $m.title.$($script:Lang); if (-not $t) { $t = $m.title.en }
                Write-Host ('    + ' + $t)
            }
        }
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
            Apply-PresetSelection $Settings $auto; Invoke-PresetModules $Modules; Pause-Return; continue
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
        Invoke-PresetModules $Modules
        Pause-Return
    }
}
