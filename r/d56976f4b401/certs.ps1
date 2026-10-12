<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): по ЯВНОМУ выбору пользователя ставит в
  доверенные хранилища Windows (LocalMachine\Root и LocalMachine\CA) российские корневые и промежуточные
  УЦ из реестра Контура (Минцифры ГУЦ, Казначейство, ФНС, Russian Trusted Root и аккредитованные УЦ).
  Нужно для входа на Госуслуги, работы с ЭЦП и порталами, подписанными этими УЦ. Устанавливаются ТОЛЬКО
  байты, закреплённые SHA-256 в манифесте выпуска (который пришёл по TLS-пину) - из сети в момент
  установки ничего не качается. Это ОСОЗНАННОЕ решение доверия: компьютер начнёт доверять сертификатам
  этих УЦ. Каждый добавленный сертификат записывается в снимок и снимается пунктом отмены по отпечатку.
  Нужны права администратора (повышение идёт через проверенный канал lib.ps1, Invoke-VerifiedElevated).
#>

param(
    [ValidateSet('install', 'revert')]
    [string]$Run,
    [string]$Root,
    [string]$Pin,
    [ValidateSet('ru', 'en')]
    [string]$Lang = 'ru'
)

$ErrorActionPreference = 'Stop'
$script:CertModuleName = 'certs.ps1'
$script:CertRegistryName = 'kontur-certs.json'
$script:FirefoxCertKeys = @(
    'HKLM:\SOFTWARE\Policies\Mozilla\Firefox\Certificates',
    'HKLM:\SOFTWARE\Policies\Mozilla\Zen\Certificates'
)

if (-not $Run) {

    function Get-CertRegistryCounts {
        $path = Join-Path $PSScriptRoot $script:CertRegistryName
        if (-not (Test-Path -LiteralPath $path)) { return @{ Root = 0; Ca = 0 } }
        try {
            $reg = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
            $r = @($reg.ROOT.PSObject.Properties).Count
            $c = @($reg.CA.PSObject.Properties).Count
            return @{ Root = $r; Ca = $c }
        }
        catch { return @{ Root = 0; Ca = 0 } }
    }

    function Start-CertsWorker([string]$Mode) {
        $rootB64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($PSScriptRoot))
        $tokens = @('-Run', "'$Mode'", '-Lang', "'$script:Lang'", '-Root', "'$rootB64'", '-Pin', "'$($script:ManifestPin)'")
        try {
            $rc = Invoke-VerifiedElevated $script:CertModuleName $tokens
            Show-ElevatedReport $rc
        }
        catch {
            if ($script:Lang -eq 'en') { Write-Host "  Could not run elevated: $(Get-ShortError $_). In the UAC prompt click Yes." -ForegroundColor Yellow }
            else { Write-Host "  Не удалось запустить с правами администратора: $(Get-ShortError $_). В окне UAC ответьте «Да»." -ForegroundColor Yellow }
            [void](Read-Host '  Enter')
        }
    }

    function Invoke-CertsScreen {
        $en = ($script:Lang -eq 'en')
        while ($true) {
            Clear-Host
            $cnt = Get-CertRegistryCounts
            Write-Host ''
            if ($en) {
                Write-Host '  Russian government certificates (Gosuslugi, digital signature)' -ForegroundColor Cyan
                Write-Host ''
                Write-Host "  Installs $($cnt.Root) root and $($cnt.Ca) intermediate certification authorities"
                Write-Host '  (Ministry of Digital Development head CA, Treasury, FTS, Russian Trusted Root'
                Write-Host '  and accredited CAs) into the Windows trust store. Needed to sign in to Gosuslugi'
                Write-Host '  and to work with digital signatures and portals issued by these authorities.'
                Write-Host ''
                Write-Host '  This is a trust decision: the computer will trust certificates from these CAs.' -ForegroundColor Yellow
                Write-Host '  Only bytes pinned by SHA-256 in the release are installed; nothing is downloaded now.' -ForegroundColor DarkGray
                Write-Host ''
                Write-Host '    [1] Install the certificates'
                Write-Host '    [r] Remove the certificates this tool added'
                Write-Host '    [0] Back'
            }
            else {
                Write-Host '  Российские сертификаты для госуслуг и ЭЦП' -ForegroundColor Cyan
                Write-Host ''
                Write-Host "  Установит $($cnt.Root) корневых и $($cnt.Ca) промежуточных удостоверяющих центра"
                Write-Host '  (Головной УЦ Минцифры, Казначейство, ФНС, Russian Trusted Root и аккредитованные УЦ)'
                Write-Host '  в доверенные хранилища Windows. Нужно для входа на Госуслуги и работы с электронной'
                Write-Host '  подписью и порталами, подписанными этими удостоверяющими центрами.'
                Write-Host ''
                Write-Host '  Это решение о доверии: компьютер начнёт доверять сертификатам этих УЦ.' -ForegroundColor Yellow
                Write-Host '  Ставятся только байты, закреплённые SHA-256 в выпуске; из сети сейчас ничего не качается.' -ForegroundColor DarkGray
                Write-Host ''
                Write-Host '    [1] Установить сертификаты'
                Write-Host '    [r] Удалить сертификаты, добавленные этим инструментом'
                Write-Host '    [0] Назад'
            }
            Write-Host ''
            if ($en) { $ask = Read-Host '  Choice' } else { $ask = Read-Host '  Выбор' }
            $ask = "$ask".Trim().ToLower()
            if ($ask -eq '0') { return }
            elseif ($ask -eq '1') { Start-CertsWorker 'install' }
            elseif ($ask -eq 'r' -or $ask -eq 'к') { Start-CertsWorker 'revert' }
        }
    }

    return
}

function Wait-Exit {}

$ProgressPreference = 'SilentlyContinue'
$WarningPreference  = 'SilentlyContinue'

function Get-PlainError($Err) {
    $m = "$($Err.Exception.Message)" -split "`r?`n" | Select-Object -First 1
    if ($m.Length -gt 160) { $m = $m.Substring(0, 160) + '...' }
    return $m
}

trap {
    Write-Host ''
    if ($Lang -eq 'en') { Write-Host "  [!!] The magic did not work: $(Get-PlainError $_)" -ForegroundColor Red }
    else { Write-Host "  [!!] Магия не сработала: $(Get-PlainError $_)" -ForegroundColor Red }
    Wait-Exit
    exit 1
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host '  [!!] Нужны права администратора. Запустите действие из меню и ответьте «Да» на запрос Windows.' -ForegroundColor Red
    Wait-Exit; exit 1
}

$workDir = $null
try { $workDir = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($Root)) } catch { }
if (-not $workDir -or -not (Test-Path -LiteralPath $workDir)) { throw 'рабочая папка не передана' }
if (-not $Pin) { throw 'манифест-пин не передан (loader не передал)' }

$sha = [Security.Cryptography.SHA256]::Create()
$manifestBytes = [IO.File]::ReadAllBytes((Join-Path $workDir 'manifest.json'))
$manifestSha = ([BitConverter]::ToString($sha.ComputeHash($manifestBytes)) -replace '-', '')
if ($manifestSha -ne "$Pin") { throw 'манифест не совпал с закреплённой контрольной суммой - ничего не менялось' }
$manifest = [Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json

$regEntry = $manifest.files | Where-Object { $_.name -eq $script:CertRegistryName } | Select-Object -First 1
if ($null -eq $regEntry) { throw "в манифесте нет записи для $script:CertRegistryName" }
$regBytes = [IO.File]::ReadAllBytes((Join-Path $workDir $script:CertRegistryName))
$regSha = ([BitConverter]::ToString($sha.ComputeHash($regBytes)) -replace '-', '')
if ($regSha -ne $regEntry.sha256) { throw "реестр сертификатов не прошёл проверку SHA" }
$registry = [Text.Encoding]::UTF8.GetString($regBytes) | ConvertFrom-Json

function Test-CertAllowed($name, $hasCondition) {
    if ($hasCondition) { return $false }
    $n = "$name".ToLower()
    if ($n -match 'тест' -or $n -match 'test') { return $false }
    return $true
}

function Get-AllowedCertSet {
    $set = @{}
    foreach ($store in 'ROOT', 'CA') {
        foreach ($p in @($registry.$store.PSObject.Properties)) {
            $e = $p.Value
            $cond = $null; if ($e.PSObject.Properties['Condition']) { $cond = $e.Condition }
            if (-not (Test-CertAllowed $e.Name $cond)) { continue }
            try {
                $der = [Convert]::FromBase64String($e.Data)
                $cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2 (, [byte[]]$der)
                $set[$cert.Thumbprint] = $true
            }
            catch { }
        }
    }
    return $set
}

function Assert-TrustedDirChain($dir) {
    $adminsSid = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $systemSid = New-Object Security.Principal.SecurityIdentifier('S-1-5-18')
    $root = [IO.Path]::GetFullPath($env:ProgramData)
    $p = [IO.Path]::GetFullPath($dir)
    $chain = @()
    while ($p -and $p.Length -gt $root.Length) {
        $chain = @($p) + $chain
        $parent = [IO.Path]::GetDirectoryName($p)
        if (-not $parent -or $parent -eq $p) { break }
        $p = $parent
    }
    foreach ($c in $chain) {
        if (-not (Test-Path -LiteralPath $c)) { continue }
        $it = Get-Item -LiteralPath $c -Force
        if ($it.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Отказ: '$c' - reparse point (junction/symlink), доверять нельзя."
        }
        $owner = (Get-Acl -LiteralPath $c).GetOwner([Security.Principal.SecurityIdentifier])
        if ($owner -ne $adminsSid -and $owner -ne $systemSid) {
            throw "Отказ: '$c' принадлежит недоверенному владельцу ($owner); путь небезопасен."
        }
    }
}

function Get-CertSnapDir {
    $parent = Join-Path $env:ProgramData 'AutoSettings.win'
    $dir = Join-Path $parent 'cert-snapshots'
    $adminsSid = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $systemSid = New-Object Security.Principal.SecurityIdentifier('S-1-5-18')
    Assert-TrustedDirChain $dir
    foreach ($d in @($parent, $dir)) {
        if (-not (Test-Path -LiteralPath $d)) { [void](New-Item -ItemType Directory -Path $d) }
        $acl = New-Object Security.AccessControl.DirectorySecurity
        $acl.SetAccessRuleProtection($true, $false)
        $acl.SetOwner($adminsSid)
        foreach ($id in @($adminsSid, $systemSid)) {
            $rule = New-Object Security.AccessControl.FileSystemAccessRule(
                $id, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
            $acl.AddAccessRule($rule)
        }
        Set-Acl -LiteralPath $d -AclObject $acl
    }
    return $dir
}

function Invoke-CertInstall {
    $snapDir = Get-CertSnapDir
    $added = New-Object System.Collections.ArrayList
    $skipped = 0
    $failed = 0
    $plan = @(
        @{ Store = 'Root'; Entries = $registry.ROOT },
        @{ Store = 'CA';   Entries = $registry.CA }
    )
    foreach ($grp in $plan) {
        $storeName = $grp.Store
        $props = @($grp.Entries.PSObject.Properties)
        $label = if ($storeName -eq 'Root') { 'Доверенные корневые' } else { 'Промежуточные' }
        $store = New-Object Security.Cryptography.X509Certificates.X509Store($storeName, 'LocalMachine')
        $store.Open('ReadWrite')
        try {
            foreach ($p in $props) {
                $e = $p.Value
                $cond = $null; if ($e.PSObject.Properties['Condition']) { $cond = $e.Condition }
                if (-not (Test-CertAllowed $e.Name $cond)) { continue }
                try {
                    $der = [Convert]::FromBase64String($e.Data)
                    $cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2 (, [byte[]]$der)
                    $tp = $cert.Thumbprint
                    $exists = @($store.Certificates.Find('FindByThumbprint', $tp, $false)).Count -gt 0
                    if ($exists) { $skipped++; continue }
                    $store.Add($cert)
                    [void]$added.Add([PSCustomObject]@{ Thumbprint = $tp; Store = $storeName; Name = $e.Name })
                    $null = $e.Name
                }
                catch { $failed++ }
            }
        }
        finally { $store.Close() }
    }

    $ffPrior = @()
    foreach ($k in $script:FirefoxCertKeys) {
        $had = $false; $prev = $null
        if (Test-Path $k) {
            $it = Get-ItemProperty -Path $k -Name 'ImportEnterpriseRoots' -ErrorAction SilentlyContinue
            if ($it) { $had = $true; $prev = $it.ImportEnterpriseRoots }
        }
        else { [void](New-Item -Path $k -Force) }
        $ffPrior += [PSCustomObject]@{ Key = $k; Had = $had; Prev = $prev }
        Set-ItemProperty -Path $k -Name 'ImportEnterpriseRoots' -Value 1 -Type DWord -Force
    }
    $ffSet = $true
    foreach ($k in $script:FirefoxCertKeys) {
        $it = Get-ItemProperty -Path $k -Name 'ImportEnterpriseRoots' -ErrorAction SilentlyContinue
        if (-not $it -or $it.ImportEnterpriseRoots -ne 1) { $ffSet = $false }
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $snapPath = Join-Path $snapDir "certs-$stamp.json"
    $utf8 = New-Object Text.UTF8Encoding $false
    $snap = @{ added = @($added); firefox = @($ffPrior); stamp = $stamp } | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText($snapPath, $snap, $utf8)

    Write-Host ''
    if ($Lang -eq 'en') {
        Write-Host "  [OK] Certificates are in place: added $($added.Count), already there $skipped." -ForegroundColor Green
        if ($failed -gt 0) { Write-Host "  [!!] Could not add: $failed. Run the installation again." -ForegroundColor Red }
        if ($ffSet) { Write-Host '  [OK] Firefox and Zen now trust the certificates stored in Windows.' -ForegroundColor Green }
        else { Write-Host '  [!!] Could not tell Firefox to trust the Windows certificates. Run the installation again.' -ForegroundColor Red }
        Write-Host '  Close all browser windows and open them again.' -ForegroundColor Cyan
    } else {
        Write-Host "  [OK] Сертификаты на месте: добавлено $($added.Count), уже были $skipped." -ForegroundColor Green
        if ($failed -gt 0) { Write-Host "  [!!] Не удалось добавить: $failed. Запустите установку ещё раз." -ForegroundColor Red }
        if ($ffSet) { Write-Host '  [OK] Firefox и Zen теперь доверяют сертификатам из Windows.' -ForegroundColor Green }
        else { Write-Host '  [!!] Не получилось включить в Firefox доверие сертификатам Windows. Запустите установку ещё раз.' -ForegroundColor Red }
        Write-Host '  Закройте все окна браузеров и откройте их заново.' -ForegroundColor Cyan
    }
}

function Invoke-CertRevert {
    $snapDir = Get-CertSnapDir
    $latest = @(Get-ChildItem -LiteralPath $snapDir -Filter 'certs-*.json' -File -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1)
    if ($latest.Count -eq 0) {
        if ($Lang -eq 'en') { Write-Host '  [OK] Nothing to remove: this tool has not added any certificates.' -ForegroundColor Green }
        else { Write-Host '  [OK] Удалять нечего: этот инструмент сертификаты не добавлял.' -ForegroundColor Green }
        return
    }
    $snap = [IO.File]::ReadAllText($latest[0].FullName, [Text.Encoding]::UTF8) | ConvertFrom-Json

    $allowed = Get-AllowedCertSet
    $removed = 0; $missing = 0; $refused = 0
    $byStore = @{}
    foreach ($a in @($snap.added)) {
        if (-not $allowed.ContainsKey("$($a.Thumbprint)")) { $refused++; continue }
        if (-not $byStore.ContainsKey($a.Store)) { $byStore[$a.Store] = New-Object System.Collections.ArrayList }
        [void]$byStore[$a.Store].Add($a)
    }
    foreach ($storeName in $byStore.Keys) {
        if ($storeName -ne 'Root' -and $storeName -ne 'CA') { continue }
        $store = New-Object Security.Cryptography.X509Certificates.X509Store($storeName, 'LocalMachine')
        $store.Open('ReadWrite')
        try {
            foreach ($a in $byStore[$storeName]) {
                $found = @($store.Certificates.Find('FindByThumbprint', $a.Thumbprint, $false))
                if ($found.Count -gt 0) { foreach ($c in $found) { $store.Remove($c) }; $removed++ }
                else { $missing++ }
            }
        }
        finally { $store.Close() }
    }

    foreach ($f in @($snap.firefox)) {
        if ($script:FirefoxCertKeys -notcontains "$($f.Key)") { continue }
        try {
            if ($f.Had) { Set-ItemProperty -Path $f.Key -Name 'ImportEnterpriseRoots' -Value $f.Prev -Type DWord -Force }
            elseif (Test-Path $f.Key) { Remove-ItemProperty -Path $f.Key -Name 'ImportEnterpriseRoots' -Force -ErrorAction SilentlyContinue }
        }
        catch { }
    }

    Remove-Item -LiteralPath $latest[0].FullName -Force -ErrorAction SilentlyContinue
    Write-Host ''
    if ($Lang -eq 'en') { Write-Host "  [OK] Removed the certificates this tool added: $removed." -ForegroundColor Green }
    else { Write-Host "  [OK] Убрали сертификаты, которые добавлял этот инструмент: $removed." -ForegroundColor Green }
}

if ($Run -eq 'install') {
    if ($Lang -eq 'en') { Write-Host '  Doing some magic with the certificates...' -ForegroundColor Cyan } else { Write-Host '  Колдуем над сертификатами...' -ForegroundColor Cyan }
    Invoke-CertInstall; Wait-Exit; exit 0
}
if ($Run -eq 'revert') {
    if ($Lang -eq 'en') { Write-Host '  Putting the certificates back the way they were...' -ForegroundColor Cyan } else { Write-Host '  Возвращаем сертификаты как было...' -ForegroundColor Cyan }
    Invoke-CertRevert; Wait-Exit; exit 0
}
