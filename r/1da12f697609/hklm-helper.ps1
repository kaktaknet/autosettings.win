$script:Lang = 'en'
$script:S = @{
    SnapUnsafe = 'Snapshot folder has unexpected permissions: {0}'
    SkipType   = 'skipped (type {0}): {1}\{2}'
}

function Write-HelperResult($obj) {
    $utf8 = New-Object Text.UTF8Encoding $false
    try { [IO.File]::WriteAllText($Hk.ResultPath, ($obj | ConvertTo-Json -Depth 6), $utf8) } catch {}
}

$result = @{
    ok = $false; mode = "$($Hk.Mode)"; applied = 0; failed = 0
    reverted = 0; skipped = 0; snapshot = $null; error = $null
}
try {
    $AllowedOps = @(
        'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows|CEIPEnable',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo|DisabledByGroupPolicy',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer|NoAutoplayfornonVolume',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection|AllowDeviceNameInDiagnosticData',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection|AllowTelemetry',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection|DisableDiagnosticDataViewer',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection|DoNotShowFeedbackNotifications',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting|Disabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search|AllowCloudSearch',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search|AllowCortana',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search|AllowSearchToUseLocation',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search|ConnectedSearchUseWeb',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search|DisableWebSearch',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search|EnableDynamicContentInWSB',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services|fAllowToGetHelp',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services|fAllowUnsolicited',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System|AllowClipboardHistory',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System|AllowCrossDeviceClipboard',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System|EnableActivityFeed',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System|PublishUserActivities',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System|UploadUserActivities',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI|AllowRecallEnablement',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI|DisableAIDataAnalysis',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI|DisableClickToDo',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint|DisableCocreator',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint|DisableImageCreator',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint|DisableGenerativeFill',
        'HKLM:\Software\Policies\Microsoft\Windows\AppPrivacy|LetAppsAccessGenerativeAI',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\TextInput|AllowLinguisticDataCollection',
        'HKLM:\Software\Policies\Microsoft\InputPersonalization|AllowInputPersonalization',
        'HKLM:\Software\Policies\Microsoft\Windows\AppPrivacy|LetAppsAccessAccountInfo',
        'HKLM:\Software\Policies\Microsoft\Windows\AppPrivacy|LetAppsAccessCalendar',
        'HKLM:\Software\Policies\Microsoft\Windows\AppPrivacy|LetAppsAccessCallHistory',
        'HKLM:\Software\Policies\Microsoft\Windows\AppPrivacy|LetAppsAccessContacts',
        'HKLM:\Software\Policies\Microsoft\Windows\AppPrivacy|LetAppsAccessEmail',
        'HKLM:\Software\Policies\Microsoft\Windows\AppPrivacy|LetAppsAccessLocation',
        'HKLM:\Software\Policies\Microsoft\Windows\AppPrivacy|LetAppsAccessMessaging',
        'HKLM:\Software\Policies\Microsoft\Windows\AppPrivacy|LetAppsAccessNotifications',
        'HKLM:\Software\Policies\Microsoft\Windows\AppPrivacy|LetAppsAccessPhone',
        'HKLM:\Software\Policies\Microsoft\Windows\AppPrivacy|LetAppsAccessRadios',
        'HKLM:\Software\Policies\Microsoft\Windows\AppPrivacy|LetAppsAccessTasks',
        'HKLM:\Software\Policies\Microsoft\Windows\AppPrivacy|LetAppsGetDiagnosticInfo',
        'HKLM:\Software\Policies\Microsoft\Windows\AppPrivacy|LetAppsRunInBackground',
        'HKLM:\Software\Policies\Microsoft\Windows\AppPrivacy|LetAppsSyncWithDevices',
        'HKLM:\Software\Policies\Microsoft\Windows\SettingSync|DisableSettingSync',
        'HKLM:\Software\Policies\Microsoft\Windows\SettingSync|DisableSettingSyncUserOverride'
    )
    function Test-OpAllowed($path, $name) {
        $p = "$path"
        if ($p -match '\.\.') { return $false }
        $key = "$p|$name"
        foreach ($a in $AllowedOps) { if ($key.Equals($a, [StringComparison]::OrdinalIgnoreCase)) { return $true } }
        return $false
    }
    foreach ($s in (@($Hk.SnapSet) + @($Hk.ApplySet))) {
        if ($null -eq $s) { continue }
        if (-not (Test-OpAllowed $s.path $s.name)) { throw "non-allowlisted HKLM op refused: $($s.path)\$($s.name)" }
        $t = "$($s.type)"
        if ($t -ne 'Remove' -and $script:AllowedTypes -notcontains $t) { throw "type refused: $t" }
    }

    if ($Hk.Mode -eq 'Apply') {
        if (@($Hk.SnapSet).Count -gt 0) {
            $result.snapshot = Save-MachineSnapshot @($Hk.SnapSet) $Hk.SnapId $Hk.Stamp
        }
        foreach ($s in @($Hk.ApplySet)) {
            if ($null -eq $s) { continue }
            if (-not (Test-OpAllowed $s.path $s.name)) { $result.failed++; continue }
            try { Set-One $s; $result.applied++ } catch { $result.failed++ }
        }
    }
    elseif ($Hk.Mode -eq 'Revert') {
        [void](Get-SnapshotDir)
        $path = Get-LatestMachineSnapshot $Hk.SnapId
        if ($path) {
            $doc = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
            foreach ($e in $doc.entries) {
                $match = @($Hk.SnapSet) | Where-Object { $_.path -eq $e.Path -and $_.name -eq $e.Name }
                if (-not $match) { $result.skipped++; continue }
                if (-not (Test-OpAllowed $e.Path $e.Name)) { $result.skipped++; continue }
                try { Restore-One $e; $result.reverted++ } catch { $result.skipped++ }
            }
        }
    }
    else { throw "unknown mode: $($Hk.Mode)" }

    $result.ok = $true
}
catch { $result.error = "$($_.Exception.Message)" }

Write-HelperResult $result
if (-not $result.ok) { exit 1 }
