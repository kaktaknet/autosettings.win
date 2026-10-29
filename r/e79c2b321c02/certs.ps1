<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): по ЯВНОМУ выбору пользователя ставит в
  доверенные хранилища Windows (LocalMachine\Root и LocalMachine\CA) российские корневые и промежуточные
  УЦ из реестра Контура (Минцифры ГУЦ, Казначейство, ФНС, Russian Trusted Root и аккредитованные УЦ).
  Нужно для входа на Госуслуги, работы с ЭЦП и порталами, подписанными этими УЦ. Устанавливаются ТОЛЬКО
  байты, закреплённые SHA-256 в манифесте выпуска (который пришёл по TLS-пину) - из сети в момент
  установки ничего не качается. Это ОСОЗНАННОЕ решение доверия: компьютер начнёт доверять сертификатам
  этих УЦ. Каждый добавленный сертификат записывается в снимок и снимается пунктом отмены по отпечатку.
  Нужны права администратора (повышение идёт через проверенный канал lib.ps1, Invoke-VerifiedElevated).
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

param(
    [ValidateSet('install', 'revert', 'purge', 'restore')]
    [string]$Run,
    [string]$Root,
    [string]$Pin,
    [string]$Only,
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

    function Get-OutdatedCerts {
        $path = Join-Path $PSScriptRoot $script:CertRegistryName
        $found = New-Object System.Collections.ArrayList
        if (-not (Test-Path -LiteralPath $path)) { return @() }
        try {
            $reg = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
            $plan = @(
                @{ Store = 'Root'; List = @($reg.ROOTREMOVE) },
                @{ Store = 'CA';   List = @($reg.CAREMOVE) }
            )
            foreach ($grp in $plan) {
                $wanted = @{}
                foreach ($t in $grp.List) { if ($t) { $wanted["$t".ToUpper()] = $true } }
                if ($wanted.Count -eq 0) { continue }
                foreach ($location in 'LocalMachine', 'CurrentUser') {
                    $store = New-Object Security.Cryptography.X509Certificates.X509Store($grp.Store, $location)
                    try {
                        $store.Open('ReadOnly')
                        foreach ($c in $store.Certificates) {
                            if (-not $wanted.ContainsKey("$($c.Thumbprint)".ToUpper())) { continue }
                            [void]$found.Add([PSCustomObject]@{
                                Store = $grp.Store; Location = $location; Thumbprint = "$($c.Thumbprint)"
                                Name = $c.GetNameInfo('SimpleName', $false); Until = $c.NotAfter.ToString('yyyy-MM-dd')
                            })
                        }
                    }
                    catch { }
                    finally { $store.Close() }
                }
            }
        }
        catch { return @() }
        return @($found)
    }

    function Confirm-OutdatedPurge($Certs) {
        $en = ($script:Lang -eq 'en')
        Write-Host ''
        if ($en) { Write-Host '  These outdated certificates will be removed from this computer:' -ForegroundColor Yellow }
        else { Write-Host '  С этого компьютера будут удалены устаревшие сертификаты:' -ForegroundColor Yellow }
        Write-Host ''
        foreach ($c in $Certs) {
            if ($en) { $kind = if ($c.Store -eq 'Root') { 'root' } else { 'intermediate' } }
            else { $kind = if ($c.Store -eq 'Root') { 'корневой' } else { 'промежуточный' } }
            if ($en) { Write-Host "    $($c.Name) ($kind, valid until $($c.Until))" }
            else { Write-Host "    $($c.Name) ($kind, действует до $($c.Until))" }
            Write-Host "      $($c.Thumbprint)" -ForegroundColor DarkGray
        }
        Write-Host ''
        if ($en) {
            Write-Host '  A copy of each one is saved first, so you can bring them back from this screen.' -ForegroundColor DarkGray
            $ans = Read-Host "  Remove these $($Certs.Count)? Type y to remove, anything else cancels (y/n)"
        }
        else {
            Write-Host '  Копия каждого сначала сохраняется, вернуть их можно с этого же экрана.' -ForegroundColor DarkGray
            $ans = Read-Host "  Удалить эти $($Certs.Count)? Введи y, чтобы удалить; любой другой ответ - отмена (y/n)"
        }
        return (Test-Yes $ans)
    }

    function Start-CertsWorker([string]$Mode, [string]$Only) {
        $rootB64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($PSScriptRoot))
        $tokens = @('-Run', "'$Mode'", '-Lang', "'$script:Lang'", '-Root', "'$rootB64'", '-Pin', "'$($script:ManifestPin)'")
        if ($Only -and $Only -match '^[0-9A-Fa-f,]+$') { $tokens += @('-Only', "'$Only'") }
        try {
            $rc = Invoke-VerifiedElevated $script:CertModuleName $tokens
            Show-ElevatedReport $rc
        }
        catch {
            if ($script:Lang -eq 'en') { Write-Host "  Could not run elevated: $(Get-ShortError $_). In the UAC prompt click Yes." -ForegroundColor Yellow }
            else { Write-Host "  Не удалось запустить с правами администратора: $(Get-ShortError $_). В окне UAC ответь «Да»." -ForegroundColor Yellow }
            [void](Read-Host '  Enter')
        }
    }

    function Invoke-CertsScreen {
        $en = ($script:Lang -eq 'en')
        while ($true) {
            $found = @(Get-OutdatedCerts)
            $machine = @($found | Where-Object { $_.Location -eq 'LocalMachine' })
            $personal = @($found | Where-Object { $_.Location -eq 'CurrentUser' })
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
                if ($machine.Count -gt 0) { Write-Host "  Outdated certificates of certification authorities found on this computer: $($machine.Count)." -ForegroundColor Yellow }
                if ($personal.Count -gt 0) { Write-Host "  Outdated certificates in your personal store: $($personal.Count). We leave those alone." -ForegroundColor DarkGray }
                Write-Host ''
                Write-Host '    [1] Install the certificates'
                Write-Host '    [r] Remove the certificates this tool added'
                if ($machine.Count -gt 0) { Write-Host "    [d] Remove the outdated certificates ($($machine.Count)) - we show the list and ask first" }
                Write-Host '    [u] Bring back the outdated certificates this tool removed'
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
                if ($machine.Count -gt 0) { Write-Host "  На компьютере найдено устаревших сертификатов удостоверяющих центров: $($machine.Count)." -ForegroundColor Yellow }
                if ($personal.Count -gt 0) { Write-Host "  Устаревших сертификатов в личном хранилище: $($personal.Count). Их не трогаем." -ForegroundColor DarkGray }
                Write-Host ''
                Write-Host '    [1] Установить сертификаты'
                Write-Host '    [r] Удалить сертификаты, добавленные этим инструментом'
                if ($machine.Count -gt 0) { Write-Host "    [d] Удалить устаревшие сертификаты ($($machine.Count)) - сначала покажем список и спросим" }
                Write-Host '    [u] Вернуть устаревшие сертификаты, которые удалил этот инструмент'
                Write-Host '    [0] Назад'
            }
            Write-Host ''
            if ($en) { $ask = Read-Host '  Choice' } else { $ask = Read-Host '  Выбор' }
            $ask = "$ask".Trim().ToLower()
            if ($ask -eq '0') { return }
            elseif ($ask -eq '1') { Start-CertsWorker 'install' }
            elseif ((Get-Key $ask) -eq 'r') { Start-CertsWorker 'revert' }
            elseif ((Get-Key $ask) -eq 'd' -and $machine.Count -gt 0) {
                if (Confirm-OutdatedPurge $machine) { Start-CertsWorker 'purge' (@($machine | ForEach-Object { $_.Thumbprint }) -join ',') }
            }
            elseif ((Get-Key $ask) -eq 'u') { Start-CertsWorker 'restore' }
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
    Write-Host '  [!!] Нужны права администратора. Запусти действие из меню и ответь «Да» на запрос Windows.' -ForegroundColor Red
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

function Read-CertSnaps($SnapDir) {
    $files = @(Get-ChildItem -LiteralPath $SnapDir -Filter 'certs-*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name)
    $added = New-Object System.Collections.ArrayList
    $seen = @{}
    $firefox = $null
    foreach ($f in $files) {
        try { $snap = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8) | ConvertFrom-Json } catch { continue }
        if ($null -eq $firefox -and @($snap.firefox).Count -gt 0) { $firefox = @($snap.firefox) }
        foreach ($a in @($snap.added)) {
            if ($a -and -not $seen.ContainsKey("$($a.Thumbprint)")) { $seen["$($a.Thumbprint)"] = $true; [void]$added.Add($a) }
        }
    }
    return @{ Files = $files; Added = $added; Firefox = $firefox }
}

function Write-CertSnap($SnapDir, $Stamp, $Added, $Firefox, $Old) {
    $path = Join-Path $SnapDir "certs-$Stamp.json"
    $utf8 = New-Object Text.UTF8Encoding $false
    [IO.File]::WriteAllText($path, (@{ added = @($Added); firefox = @($Firefox); stamp = $Stamp } | ConvertTo-Json -Depth 6), $utf8)
    foreach ($f in @($Old)) { if ($f.FullName -ne $path) { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue } }
}

function Invoke-CertInstall {
    $snapDir = Get-CertSnapDir
    $prior = Read-CertSnaps $snapDir
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $added = New-Object System.Collections.ArrayList
    foreach ($a in $prior.Added) { [void]$added.Add($a) }
    $skipped = 0
    $failed = 0
    $plan = @(
        @{ Store = 'Root'; Entries = $registry.ROOT },
        @{ Store = 'CA';   Entries = $registry.CA }
    )
    $todo = New-Object System.Collections.ArrayList
    foreach ($grp in $plan) {
        $storeName = $grp.Store
        $store = New-Object Security.Cryptography.X509Certificates.X509Store($storeName, 'LocalMachine')
        $store.Open('ReadOnly')
        try {
            foreach ($p in @($grp.Entries.PSObject.Properties)) {
                $e = $p.Value
                $cond = $null; if ($e.PSObject.Properties['Condition']) { $cond = $e.Condition }
                if (-not (Test-CertAllowed $e.Name $cond)) { continue }
                try {
                    $der = [Convert]::FromBase64String($e.Data)
                    $cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2 (, [byte[]]$der)
                    if (@($store.Certificates.Find('FindByThumbprint', $cert.Thumbprint, $false)).Count -gt 0) { $skipped++; continue }
                    [void]$todo.Add(@{ Cert = $cert; Store = $storeName; Name = $e.Name })
                }
                catch { $failed++ }
            }
        }
        finally { $store.Close() }
    }
    $planned = New-Object System.Collections.ArrayList
    foreach ($a in $added) { [void]$planned.Add($a) }
    foreach ($t in $todo) { [void]$planned.Add([PSCustomObject]@{ Thumbprint = $t.Cert.Thumbprint; Store = $t.Store; Name = $t.Name }) }
    $ffPlan = $prior.Firefox
    if ($null -eq $ffPlan) {
        $ffPlan = @()
        foreach ($fk in $script:FirefoxCertKeys) {
            $it = Get-ItemProperty -Path $fk -Name 'ImportEnterpriseRoots' -ErrorAction SilentlyContinue
            $prev = $null
            if ($it) { $prev = $it.ImportEnterpriseRoots }
            $ffPlan += [PSCustomObject]@{ Key = $fk; Had = [bool]$it; Prev = $prev }
        }
    }
    Write-CertSnap $snapDir $stamp $planned $ffPlan $prior.Files

    $fresh = 0
    foreach ($storeName in @('Root', 'CA')) {
        $mine = @($todo | Where-Object { $_.Store -eq $storeName })
        if ($mine.Count -eq 0) { continue }
        $store = New-Object Security.Cryptography.X509Certificates.X509Store($storeName, 'LocalMachine')
        $store.Open('ReadWrite')
        try {
            foreach ($t in $mine) {
                try {
                    $store.Add($t.Cert)
                    [void]$added.Add([PSCustomObject]@{ Thumbprint = $t.Cert.Thumbprint; Store = $storeName; Name = $t.Name })
                    $fresh++
                }
                catch { $failed++ }
            }
        }
        finally { $store.Close() }
    }

    foreach ($k in $script:FirefoxCertKeys) {
        if (-not (Test-Path $k)) { [void](New-Item -Path $k -Force) }
        Set-ItemProperty -Path $k -Name 'ImportEnterpriseRoots' -Value 1 -Type DWord -Force
    }
    $ffSet = $true
    foreach ($k in $script:FirefoxCertKeys) {
        $it = Get-ItemProperty -Path $k -Name 'ImportEnterpriseRoots' -ErrorAction SilentlyContinue
        if (-not $it -or $it.ImportEnterpriseRoots -ne 1) { $ffSet = $false }
    }

    Write-CertSnap $snapDir $stamp $added $ffPlan @()

    Write-Host ''
    if ($Lang -eq 'en') {
        Write-Host "  [OK] Certificates are in place: added $fresh, already there $skipped." -ForegroundColor Green
        if ($failed -gt 0) { Write-Host "  [!!] Could not add: $failed. Run the installation again." -ForegroundColor Red }
        if ($ffSet) { Write-Host '  [OK] Firefox and Zen now trust the certificates stored in Windows.' -ForegroundColor Green }
        else { Write-Host '  [!!] Could not tell Firefox to trust the Windows certificates. Run the installation again.' -ForegroundColor Red }
        Write-Host '  Close all browser windows and open them again.' -ForegroundColor Cyan
    } else {
        Write-Host "  [OK] Сертификаты на месте: добавлено $fresh, уже были $skipped." -ForegroundColor Green
        if ($failed -gt 0) { Write-Host "  [!!] Не удалось добавить: $failed. Запусти установку ещё раз." -ForegroundColor Red }
        if ($ffSet) { Write-Host '  [OK] Firefox и Zen теперь доверяют сертификатам из Windows.' -ForegroundColor Green }
        else { Write-Host '  [!!] Не получилось включить в Firefox доверие сертификатам Windows. Запусти установку ещё раз.' -ForegroundColor Red }
        Write-Host '  Закрой все окна браузеров и открой их заново.' -ForegroundColor Cyan
    }
}

function Invoke-CertRevert {
    $snapDir = Get-CertSnapDir
    $all = Read-CertSnaps $snapDir
    if (@($all.Files).Count -eq 0) {
        if ($Lang -eq 'en') { Write-Host '  [OK] Nothing to remove: this tool has not added any certificates.' -ForegroundColor Green }
        else { Write-Host '  [OK] Удалять нечего: этот инструмент сертификаты не добавлял.' -ForegroundColor Green }
        return
    }
    $snap = @{ added = @($all.Added); firefox = @($all.Firefox | Where-Object { $_ }) }

    $allowed = Get-AllowedCertSet
    $removed = 0; $missing = 0; $refused = 0; $failed = 0
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
                try {
                    $found = @($store.Certificates.Find('FindByThumbprint', $a.Thumbprint, $false))
                    if ($found.Count -gt 0) { foreach ($c in $found) { $store.Remove($c) }; $removed++ }
                    else { $missing++ }
                }
                catch { $failed++ }
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

    if ($failed -eq 0 -and $refused -eq 0) { foreach ($f in @($all.Files)) { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue } }
    Write-Host ''
    if ($Lang -eq 'en') {
        Write-Host "  [OK] Removed the certificates this tool added: $removed." -ForegroundColor Green
        if ($failed -gt 0) { Write-Host "  [!!] Could not remove: $failed. Run it again." -ForegroundColor Red }
        if ($refused -gt 0) { Write-Host "  [!!] Skipped as not from our list: $refused." -ForegroundColor Red }
    } else {
        Write-Host "  [OK] Убрали сертификаты, которые добавлял этот инструмент: $removed." -ForegroundColor Green
        if ($failed -gt 0) { Write-Host "  [!!] Не удалось убрать: $failed. Запусти ещё раз." -ForegroundColor Red }
        if ($refused -gt 0) { Write-Host "  [!!] Пропущено как не входящие в наш список: $refused." -ForegroundColor Red }
    }
}

function Get-OutdatedSet {
    $set = @{ Root = @{}; CA = @{} }
    foreach ($t in @($registry.ROOTREMOVE)) { if ($t) { $set.Root["$t".ToUpper()] = $true } }
    foreach ($t in @($registry.CAREMOVE)) { if ($t) { $set.CA["$t".ToUpper()] = $true } }
    return $set
}

function Invoke-OutdatedPurge {
    $snapDir = Get-CertSnapDir
    $set = Get-OutdatedSet
    $confirmed = @{}
    foreach ($t in "$Only".Split(',')) { if ($t -match '^[0-9A-Fa-f]{40}$') { $confirmed[$t.ToUpper()] = $true } }
    if ($confirmed.Count -eq 0) { throw 'удаление не подтверждено: список подтверждённых сертификатов пуст' }
    $saved = New-Object System.Collections.ArrayList
    foreach ($storeName in 'Root', 'CA') {
        $store = New-Object Security.Cryptography.X509Certificates.X509Store($storeName, 'LocalMachine')
        $store.Open('ReadOnly')
        try {
            foreach ($c in $store.Certificates) {
                if (-not $set[$storeName].ContainsKey("$($c.Thumbprint)".ToUpper())) { continue }
                if (-not $confirmed.ContainsKey("$($c.Thumbprint)".ToUpper())) { continue }
                $withProps = $null
                try { $withProps = [Convert]::ToBase64String($c.Export('SerializedCert')) } catch { }
                [void]$saved.Add([PSCustomObject]@{
                    Store = $storeName; Thumbprint = "$($c.Thumbprint)"
                    Name = $c.GetNameInfo('SimpleName', $false); Data = [Convert]::ToBase64String($c.RawData)
                    Serialized = $withProps
                })
            }
        }
        finally { $store.Close() }
    }
    Write-Host ''
    if ($saved.Count -eq 0) {
        if ($Lang -eq 'en') { Write-Host '  [OK] No outdated certificates on this computer.' -ForegroundColor Green }
        else { Write-Host '  [OK] Устаревших сертификатов на компьютере нет.' -ForegroundColor Green }
        return
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $snapPath = Join-Path $snapDir "outdated-$stamp.json"
    $utf8 = New-Object Text.UTF8Encoding $false
    [IO.File]::WriteAllText($snapPath, (@{ removed = @($saved); stamp = $stamp } | ConvertTo-Json -Depth 6), $utf8)

    $removed = 0; $failed = 0
    foreach ($storeName in 'Root', 'CA') {
        $store = New-Object Security.Cryptography.X509Certificates.X509Store($storeName, 'LocalMachine')
        $store.Open('ReadWrite')
        try {
            foreach ($a in @($saved | Where-Object { $_.Store -eq $storeName })) {
                try {
                    foreach ($c in @($store.Certificates.Find('FindByThumbprint', $a.Thumbprint, $false))) { $store.Remove($c) }
                    $removed++
                }
                catch { $failed++ }
            }
        }
        finally { $store.Close() }
    }
    if ($Lang -eq 'en') {
        Write-Host "  [OK] Outdated certificates removed: $removed. You can bring them back from the same screen." -ForegroundColor Green
        if ($failed -gt 0) { Write-Host "  [!!] Could not remove: $failed." -ForegroundColor Red }
    } else {
        Write-Host "  [OK] Устаревших сертификатов удалено: $removed. Вернуть их можно с этого же экрана." -ForegroundColor Green
        if ($failed -gt 0) { Write-Host "  [!!] Не удалось удалить: $failed." -ForegroundColor Red }
    }
}

function Invoke-OutdatedRestore {
    $snapDir = Get-CertSnapDir
    $latest = @(Get-ChildItem -LiteralPath $snapDir -Filter 'outdated-*.json' -File -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1)
    Write-Host ''
    if ($latest.Count -eq 0) {
        if ($Lang -eq 'en') { Write-Host '  [OK] Nothing to bring back: this tool has not removed any outdated certificates.' -ForegroundColor Green }
        else { Write-Host '  [OK] Возвращать нечего: этот инструмент устаревшие сертификаты не удалял.' -ForegroundColor Green }
        return
    }
    $snap = [IO.File]::ReadAllText($latest[0].FullName, [Text.Encoding]::UTF8) | ConvertFrom-Json

    $set = Get-OutdatedSet
    $restored = 0; $refused = 0; $failed = 0
    foreach ($storeName in 'Root', 'CA') {
        $mine = @(@($snap.removed) | Where-Object { "$($_.Store)" -eq $storeName })
        if ($mine.Count -eq 0) { continue }
        $store = New-Object Security.Cryptography.X509Certificates.X509Store($storeName, 'LocalMachine')
        $store.Open('ReadWrite')
        try {
            foreach ($a in $mine) {
                try {
                    $der = [Convert]::FromBase64String("$($a.Data)")
                    $cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2 (, [byte[]]$der)
                    if ($a.PSObject.Properties['Serialized'] -and $a.Serialized) {
                        try {
                            $full = New-Object Security.Cryptography.X509Certificates.X509Certificate2 (, [byte[]][Convert]::FromBase64String("$($a.Serialized)"))
                            if ($full.Thumbprint -eq $cert.Thumbprint) { $cert = $full }
                        }
                        catch { }
                    }
                    if (-not $set[$storeName].ContainsKey("$($cert.Thumbprint)".ToUpper())) { $refused++; continue }
                    if (@($store.Certificates.Find('FindByThumbprint', $cert.Thumbprint, $false)).Count -eq 0) { $store.Add($cert) }
                    $restored++
                }
                catch { $failed++ }
            }
        }
        finally { $store.Close() }
    }
    if ($failed -eq 0 -and $refused -eq 0) { Remove-Item -LiteralPath $latest[0].FullName -Force -ErrorAction SilentlyContinue }
    if ($Lang -eq 'en') {
        Write-Host "  [OK] Outdated certificates brought back: $restored." -ForegroundColor Green
        if ($refused -gt 0) { Write-Host "  [!!] Skipped as not from the list: $refused." -ForegroundColor Red }
        if ($failed -gt 0) { Write-Host "  [!!] Could not bring back: $failed. Run it again." -ForegroundColor Red }
    } else {
        Write-Host "  [OK] Устаревших сертификатов возвращено: $restored." -ForegroundColor Green
        if ($refused -gt 0) { Write-Host "  [!!] Пропущено как не входящие в список: $refused." -ForegroundColor Red }
        if ($failed -gt 0) { Write-Host "  [!!] Не удалось вернуть: $failed. Запусти ещё раз." -ForegroundColor Red }
    }
}

if ($Run -eq 'install') {
    if ($Lang -eq 'en') { Write-Host '  Doing some magic with the certificates...' -ForegroundColor Cyan } else { Write-Host '  Колдуем над сертификатами...' -ForegroundColor Cyan }
    Invoke-CertInstall; Wait-Exit; exit 0
}
if ($Run -eq 'revert') {
    if ($Lang -eq 'en') { Write-Host '  Putting the certificates back the way they were...' -ForegroundColor Cyan } else { Write-Host '  Возвращаем сертификаты как было...' -ForegroundColor Cyan }
    Invoke-CertRevert; Wait-Exit; exit 0
}
if ($Run -eq 'purge') {
    if ($Lang -eq 'en') { Write-Host '  Clearing out the outdated certificates...' -ForegroundColor Cyan } else { Write-Host '  Колдуем над устаревшими сертификатами...' -ForegroundColor Cyan }
    Invoke-OutdatedPurge; Wait-Exit; exit 0
}
if ($Run -eq 'restore') {
    if ($Lang -eq 'en') { Write-Host '  Bringing the outdated certificates back...' -ForegroundColor Cyan } else { Write-Host '  Возвращаем устаревшие сертификаты...' -ForegroundColor Cyan }
    Invoke-OutdatedRestore; Wait-Exit; exit 0
}
