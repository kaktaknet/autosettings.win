# MACHINE-READABLE INTENT: a terminal convenience preset; no hidden behavior, nothing sent out.
# License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
# Redistribution must keep this notice and the LICENSE and NOTICE files: https://github.com/kaktaknet/autosettings.win

if ($global:__AS_PROFILE_LOADED) { return }
$global:__AS_PROFILE_LOADED = $true

$Global:ProfileStartTime = Get-Date
$ASLang = '@ASLANG@'
if ($ASLang -notin @('ru', 'en')) { $ASLang = 'ru' }
$ASS = @{
    ru = @{
        Ready = 'PowerShell готов к работе!'; Help = 'Справка:'; DockerClean = 'Очистка Docker...'
        HelpTitle = 'СПРАВКА ПО ПРОФИЛЮ'; SysTitle = 'СИСТЕМНАЯ ИНФОРМАЦИЯ'; Tools = 'Инструменты:'
    }
    en = @{
        Ready = 'PowerShell is ready!'; Help = 'Help:'; DockerClean = 'Cleaning Docker...'
        HelpTitle = 'PROFILE HELP'; SysTitle = 'SYSTEM INFORMATION'; Tools = 'Tools:'
    }
}[$ASLang]

$Host.UI.RawUI.WindowTitle = "PowerShell $($Host.Version) - $env:USERNAME@$env:COMPUTERNAME"
$env:EDITOR = 'code'
$env:PAGER = 'less'

if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine -Force -ErrorAction SilentlyContinue
    try {
        Set-PSReadLineOption -EditMode Emacs -HistorySearchCursorMovesToEnd `
            -MaximumHistoryCount 32767 -HistoryNoDuplicates `
            -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView -BellStyle None
        Set-PSReadLineKeyHandler -Chord 'Ctrl+f' -Function ForwardWord
        Set-PSReadLineKeyHandler -Chord 'Ctrl+l' -Function ClearScreen
        Set-PSReadLineKeyHandler -Chord 'UpArrow' -Function HistorySearchBackward
        Set-PSReadLineKeyHandler -Chord 'DownArrow' -Function HistorySearchForward
    }
    catch { }
}
Import-Module CompletionPredictor -ErrorAction SilentlyContinue
Import-Module Terminal-Icons -ErrorAction SilentlyContinue

if (-not $global:__AS_OMP) {
    $ompExe = (Get-Command oh-my-posh -ErrorAction SilentlyContinue).Source
    if (-not $ompExe) {
        $ompCand = Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\bin\oh-my-posh.exe'
        if (Test-Path $ompCand) { $ompExe = $ompCand; $env:PATH = (Split-Path $ompCand) + ';' + $env:PATH }
    }
    if ($ompExe) {
        if (-not $env:POSH_THEMES_PATH) {
            $ompThemes = Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\themes'
            if (Test-Path $ompThemes) { $env:POSH_THEMES_PATH = $ompThemes }
        }
        $ompLoaded = $false
        $ompConfig = Join-Path $HOME '.config\ohmyposh\autosettings.omp.json'
        if (-not (Test-Path $ompConfig)) { $ompConfig = 'atomic' }
        try { & $ompExe init pwsh --config $ompConfig | Invoke-Expression; $ompLoaded = $true } catch { }
        if (-not $ompLoaded) { try { & $ompExe init pwsh | Invoke-Expression; $ompLoaded = $true } catch { } }
        if (-not $ompLoaded) {
            function prompt {
                $loc = $PWD.Path
                if ($loc.Length -gt 40) { $loc = '...' + $loc.Substring($loc.Length - 37) }
                "PS $loc`n> "
            }
        }
        if ($ompLoaded) { $global:__AS_OMP = $true }
    }
}

Set-Alias -Name 'l' -Value 'Get-ChildItem' -ErrorAction SilentlyContinue
Set-Alias -Name 'grep' -Value 'Select-String' -ErrorAction SilentlyContinue
Set-Alias -Name 'which' -Value 'Get-Command' -ErrorAction SilentlyContinue
Set-Alias -Name 'g' -Value 'git' -ErrorAction SilentlyContinue
Set-Alias -Name 'edit' -Value 'code' -ErrorAction SilentlyContinue

function ll { param([string]$Path = '.') Get-ChildItem -Path $Path | Format-Table Name, Mode, LastWriteTime, Length -AutoSize }
function la { param([string]$Path = '.') Get-ChildItem -Path $Path -Force | Format-Table Name, Mode, LastWriteTime, Length -AutoSize }
function cd~ { Set-Location ~ }
function cdd { Set-Location ~/Documents }
function cdc { if (Test-Path ~/Code) { Set-Location ~/Code } else { Set-Location ~ } }
function touch { param([string]$Name) if (Test-Path $Name) { (Get-Item $Name).LastWriteTime = Get-Date } else { New-Item -ItemType File -Name $Name -Force | Out-Null } }
function mkcd { param([string]$Name) New-Item -ItemType Directory -Name $Name -Force | Out-Null; Set-Location $Name }

function docker-check { $null -ne (Get-Command docker -ErrorAction SilentlyContinue) }
function docker-ps { docker ps $args }
function docker-images { docker images $args }
function docker-clean { Write-Host $ASS.DockerClean -ForegroundColor Yellow; docker system prune -f }
if (docker-check) {
    Set-Alias -Name 'd' -Value 'docker' -ErrorAction SilentlyContinue
    Set-Alias -Name 'dps' -Value 'docker-ps' -ErrorAction SilentlyContinue
    Set-Alias -Name 'di' -Value 'docker-images' -ErrorAction SilentlyContinue
    Set-Alias -Name 'dclean' -Value 'docker-clean' -ErrorAction SilentlyContinue
}

function npm-dev { npm run dev }
function npm-build { npm run build }
if (Get-Command node -ErrorAction SilentlyContinue) {
    Set-Alias -Name 'n' -Value 'node' -ErrorAction SilentlyContinue
    Set-Alias -Name 'nd' -Value 'npm-dev' -ErrorAction SilentlyContinue
    Set-Alias -Name 'nb' -Value 'npm-build' -ErrorAction SilentlyContinue
}

function claude-continue { claude -c }
if (Get-Command claude -ErrorAction SilentlyContinue) {
    Set-Alias -Name 'cc' -Value 'claude-continue' -ErrorAction SilentlyContinue
}

function Get-PublicIP {
    try { Write-Host "IP: $(Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 5)" -ForegroundColor Green }
    catch { Write-Host 'IP?' -ForegroundColor Red }
}
function Edit-Profile { code $PROFILE }
function Reload-Profile { . $PROFILE }
function Get-ProfileHelp {
    Write-Host ''
    Write-Host "  $($ASS.HelpTitle)" -ForegroundColor Cyan
    Write-Host '  ll, la            Get-ChildItem' -ForegroundColor White
    Write-Host '  cd~, cdd, cdc     navigation' -ForegroundColor White
    Write-Host '  touch, mkcd       files' -ForegroundColor White
    Write-Host '  d, dps, di        docker' -ForegroundColor White
    Write-Host '  n, nd, nb         node / npm' -ForegroundColor White
    Write-Host '  g                 git' -ForegroundColor White
    Write-Host '  cc                claude -c' -ForegroundColor White
    Write-Host '  myip, Edit-Profile, Reload-Profile' -ForegroundColor White
    Write-Host ''
}
Set-Alias -Name 'help' -Value 'Get-ProfileHelp' -ErrorAction SilentlyContinue
Set-Alias -Name 'myip' -Value 'Get-PublicIP' -ErrorAction SilentlyContinue

$PSDefaultParameterValues = @{ 'Out-File:Encoding' = 'utf8'; 'Export-Csv:NoTypeInformation' = $true }

$loadTime = (Get-Date) - $Global:ProfileStartTime
Write-Host ''
Write-Host "$($ASS.Ready) " -NoNewline -ForegroundColor Green
Write-Host "($([math]::Round($loadTime.TotalMilliseconds))ms)  " -NoNewline -ForegroundColor Yellow
Write-Host "$($ASS.Help) help" -ForegroundColor Blue
