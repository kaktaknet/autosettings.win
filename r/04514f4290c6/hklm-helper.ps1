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
        'HKLM:\Software\Policies\Microsoft\Windows\SettingSync|DisableSettingSyncUserOverride',
        'HKLM:\SOFTWARE\Policies\WindowsNotepad|DisableAIFeatures',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer|HideRecommendedSection',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR|AllowGameDVR',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization|DODownloadMode',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata|PreventDeviceMetadataFromNetwork',
        'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings|IsContinuousInnovationOptedIn',
        'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power|HiberbootEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|HubsSidebarEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|EdgeHistoryAISearchEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|GenAILocalFoundationalModelSettings',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|NewTabPageContentEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|NewTabPageHideDefaultTopSites',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|EdgeShoppingAssistantEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|ShowRecommendationsEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|SpotlightExperiencesAndRecommendationsEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|DefaultBrowserSettingsCampaignEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|ShowAcrobatSubscriptionButton',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|TabServicesEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|AlternateErrorPagesEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|UserFeedbackAllowed',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|PersonalizationReportingEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|DiagnosticData',
        'HKLM:\SOFTWARE\Policies\Google\Chrome|GeminiSettings',
        'HKLM:\SOFTWARE\Policies\Google\Chrome|GeminiSparkSettings',
        'HKLM:\SOFTWARE\Policies\Google\Chrome|AIModeSettings',
        'HKLM:\SOFTWARE\Policies\Google\Chrome|HelpMeWriteSettings',
        'HKLM:\SOFTWARE\Policies\Google\Chrome|HistorySearchSettings',
        'HKLM:\SOFTWARE\Policies\Google\Chrome|TabCompareSettings',
        'HKLM:\SOFTWARE\Policies\Google\Chrome|CreateThemesSettings',
        'HKLM:\SOFTWARE\Policies\Google\Chrome|DevToolsGenAiSettings',
        'HKLM:\SOFTWARE\Policies\Google\Chrome|AutofillPredictionSettings',
        'HKLM:\SOFTWARE\Policies\Google\Chrome|VoiceTypingSettings',
        'HKLM:\SOFTWARE\Policies\Google\Chrome|GenAILocalFoundationalModelSettings',
        'HKLM:\SOFTWARE\Policies\Google\Chrome|SearchContentSharingSettings',
        'HKLM:\SOFTWARE\Policies\Google\Chrome|SmartTabSharingSettings',
        'HKLM:\SOFTWARE\Policies\Google\Chrome|ThirdPartyAiChatSettings',
        'HKLM:\SOFTWARE\Policies\Google\Chrome|ChromeSuggestionsSettings',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer|NoUseStoreOpenWith',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer|NoNewAppAlert',
        'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate|CreateDesktopShortcut{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer|HideRecentlyAddedApps',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer|NoStartMenuMFUprogramsList',
        'HKLM:\SOFTWARE\Policies\Microsoft\Dsh|AllowNewsAndInterests',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds|EnableFeeds',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System|EnableFirstLogonAnimation',
        'HKLM:\SOFTWARE\Policies\Google\Chrome|AutofillGenAiSettings',
        'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment|DOTNET_CLI_TELEMETRY_OPTOUT',
        'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment|POWERSHELL_TELEMETRY_OPTOUT',
        'HKLM:\Software\Policies\Microsoft\VisualStudio\SQM|OptIn',
        'HKLM:\SOFTWARE\Policies\Mozilla\Firefox|DisableTelemetry',
        'HKLM:\SOFTWARE\Policies\Mozilla\Firefox|DisableFirefoxStudies',
        'HKLM:\SOFTWARE\Policies\Mozilla\Firefox|DisableDefaultBrowserAgent',
        'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem|LongPathsEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Maps|AutoDownloadAndUpdateMapData',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|ConfigureDoNotTrack',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|MicrosoftEdgeInsiderPromotionEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|ShowMicrosoftRewards',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|HideFirstRunExperience',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|EdgeCollectionsEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|WebWidgetAllowed',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|EdgeAssetDeliveryServiceEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate|CreateDesktopShortcutDefault',
        'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl|DisplayParameters',
        'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl|DisableEmoticon',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System|VerboseStatus',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System|DisableAcrylicBackgroundOnLogon',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization|NoLockScreen',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat|AITEnable',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat|DisableInventory',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection|DisableOneSettingsDownloads',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE|DisablePrivacyExperience',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat|DisableUAR',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System|EnableFontProviders',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection|LimitDiagnosticLogCollection',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection|LimitDumpCollection',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Software Protection Platform|NoGenTicket',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers|DisableHTTPPrinting',
        'HKLM:\SOFTWARE\Policies\Microsoft\WMDRM|DisableOnline',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat|DisablePropPage',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers|DisableWebPnPDownload',
        'HKLM:\SOFTWARE\Policies\Microsoft\EventViewer|MicrosoftEventVwrDisableLinks',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer|NoInternetOpenWith',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer|NoOnlinePrintsWizard',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer|NoPublishingWizard',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer|NoWebServices',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Messaging|AllowMessageSync',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer|AllowOnlineTips',
        'HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace|AllowSuggestedAppsInWindowsInkWorkspace',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI|DisableSettingsAgent',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors|DisableLocationScripting',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System|DisableLockScreenAppNotifications',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy|LetAppsAccessHumanPresence',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy|LetAppsAccessMotion',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy|LetAppsAccessTrustedDevices',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy|LetAppsActivateWithVoice',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy|LetAppsActivateWithVoiceAboveLock',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Connect|AllowProjectionToPC',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors|DisableSensors',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors|DisableWindowsLocationProvider',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System|EnableCdp',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System|EnableMmx',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WwanSvc\CellularDataAccess|LetAppsAccessCellularData',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy|LetAppsAccessGraphicsCaptureProgrammatic',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy|LetAppsAccessGraphicsCaptureWithoutBorder',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System|MSAOptional',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications|NoCloudApplicationNotification',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization|NoLockScreenCamera',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|AIGenThemesEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|BuiltInAIAPIsEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|Edge3PSerpTelemetryEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|ExperimentationAndConfigurationServiceControl',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|ImportOnEachLaunch',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|SearchbarAllowed',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|SearchbarIsEnabledOnStartup',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|StandaloneHubsSidebarEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|StartupBoostEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|AutofillAddressEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|AutofillCreditCardEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|BlockThirdPartyCookies',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|BrowserSignin',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|InAppSupportEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|NewTabPageAllowedBackgroundTypes',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|NewTabPageQuickLinksEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|ResolveNavigationErrorsUseWebService',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|SearchSuggestEnabled',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge|TrackingPrevention',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search|AllowCortanaAboveLock',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search|PreventRemoteQueries',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer|DisableGraphRecentItems',
        'HKLM:\SOFTWARE\Policies\Microsoft\OneDrive|KFMBlockOptIn',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation|DisableStartupSound',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\EditionOverrides|UserSetting_DisableStartupSound',
        'HKLM:\SOFTWARE\Policies\Microsoft\PushToInstall|DisablePushToInstall',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer|HideRecommendedPersonalizedSites',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer|ShowOrHideMostUsedApps'
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
        if ($t -ne 'Remove' -and $t -ne 'Flags' -and $script:AllowedTypes -notcontains $t) { throw "type refused: $t" }
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
