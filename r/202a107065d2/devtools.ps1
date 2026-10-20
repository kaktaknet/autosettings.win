<#
MACHINE-READABLE INTENT (для человека или ИИ-ревьюера): по ЯВНОМУ выбору ставит, обновляет и удаляет программы из фиксированных списков через winget
  (источник winget, установщики с закреплённой суммой) и консольных ИИ-агентов через winget или npm.
  Удаление - только выбранного, после вопроса по имени.
  License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0). Copyright 2026 kaktak.net.
  Redistribution must keep this notice and the LICENSE and NOTICE files:
  https://github.com/kaktaknet/autosettings.win
#>

$script:DevToolItems = @(
    @{ Kind = 'wsl';
       Name = @{ ru = 'WSL 2 + Ubuntu (Linux в Windows: tmux и Unix-инструменты; нужна перезагрузка)';
                 en = 'WSL 2 + Ubuntu (Linux on Windows: tmux and Unix tools; reboot required)' } },
    @{ Kind = 'winget'; Id = 'Git.Git';                Check = 'git';  Override = $null;
       Name = @{ ru = 'Git - система контроля версий'; en = 'Git - version control' } },
    @{ Kind = 'winget'; Id = 'GitHub.cli';             Check = 'gh';   Override = $null;
       Name = @{ ru = 'GitHub CLI (gh) - работа с GitHub из консоли'; en = 'GitHub CLI (gh) - GitHub from the console' } },
    @{ Kind = 'winget'; Id = 'Microsoft.VisualStudioCode'; Check = 'code'; Override = $null;
       Name = @{ ru = 'Visual Studio Code - редактор кода'; en = 'Visual Studio Code - code editor' } },
    @{ Kind = 'winget'; Id = 'Microsoft.VisualStudio.2022.BuildTools'; Check = $null;
       Override = '--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --quiet --wait --norestart';
       Name = @{ ru = 'Build Tools C++ (компиляторы для нативных npm-модулей, несколько ГБ)';
                 en = 'Build Tools C++ (compilers for native npm modules, several GB)' } },
    @{ Kind = 'winget'; Id = 'Python.Python.3.13';     Check = 'python'; Override = $null;
       Name = @{ ru = 'Python 3 (нужен node-gyp для сборки нативных npm-модулей)';
                 en = 'Python 3 (node-gyp needs it to build native npm modules)' } },
    @{ Kind = 'winget'; Id = 'BurntSushi.ripgrep.MSVC'; Check = 'rg';   Override = $null;
       Name = @{ ru = 'ripgrep (rg) - очень быстрый поиск по коду';
                 en = 'ripgrep (rg) - very fast code search' } },
    @{ Kind = 'winget'; Id = 'sharkdp.fd';             Check = 'fd';    Override = $null;
       Name = @{ ru = 'fd - быстрый поиск файлов (замена find)';
                 en = 'fd - fast file finder (find replacement)' } },
    @{ Kind = 'winget'; Id = 'jqlang.jq';              Check = 'jq';    Override = $null;
       Name = @{ ru = 'jq - обработка JSON в консоли';
                 en = 'jq - JSON processing on the command line' } },
    @{ Kind = 'winget'; Id = 'junegunn.fzf';           Check = 'fzf';   Override = $null;
       Name = @{ ru = 'fzf - интерактивный нечёткий поиск';
                 en = 'fzf - interactive fuzzy finder' } },
    @{ Kind = 'winget'; Id = 'sharkdp.bat';            Check = 'bat';   Override = $null;
       Name = @{ ru = 'bat - просмотр файлов с подсветкой (замена cat)';
                 en = 'bat - file viewer with highlighting (cat replacement)' } },
    @{ Kind = 'winget'; Id = 'astral-sh.uv';           Check = 'uv';    Override = $null;
       Name = @{ ru = 'uv - быстрый менеджер пакетов и запуск Python';
                 en = 'uv - fast Python package manager and runner' } },
    @{ Kind = 'winget'; Id = 'OpenJS.NodeJS.LTS';      Check = 'node';   Override = $null;
       Name = @{ ru = 'Node.js LTS - среда JavaScript и npm';
                 en = 'Node.js LTS - JavaScript runtime and npm' } }
)

$script:AiAgentItems = @(
    @{ Kind = 'winget'; Id = 'Anthropic.ClaudeCode';   Check = 'claude'; Override = $null;
       Name = @{ ru = 'Claude Code - ИИ-агент в консоли (Anthropic)';
                 en = 'Claude Code - console AI agent (Anthropic)' } },
    @{ Kind = 'winget'; Id = 'OpenAI.Codex';           Check = 'codex';  Override = $null;
       Name = @{ ru = 'Codex - ИИ-агент в консоли (OpenAI)';
                 en = 'Codex - console AI agent (OpenAI)' } },
    @{ Kind = 'winget'; Id = 'charmbracelet.crush';    Check = 'crush';  Override = $null;
       Name = @{ ru = 'Crush - ИИ-агент в консоли (Charm, работает с разными моделями)';
                 en = 'Crush - console AI agent (Charm, multi-model)' } },
    @{ Kind = 'winget'; Id = 'GitHub.Copilot';         Check = 'copilot'; Override = $null;
       Name = @{ ru = 'Copilot CLI - ИИ-агент в консоли (GitHub)';
                 en = 'Copilot CLI - console AI agent (GitHub)' } },
    @{ Kind = 'winget'; Id = 'Sourcegraph.Amp';        Check = 'amp';    Override = $null;
       Name = @{ ru = 'Amp - ИИ-агент в консоли (Sourcegraph)';
                 en = 'Amp - console AI agent (Sourcegraph)' } },
    @{ Kind = 'winget'; Id = 'KiloCode.Kilo';          Check = 'kilo';   Override = $null;
       Name = @{ ru = 'Kilo - ИИ-агент в консоли (открытый, разные модели)';
                 en = 'Kilo - console AI agent (open, multi-model)' } },
    @{ Kind = 'winget'; Id = 'Google.AntigravityCLI';  Check = 'agy';    Override = $null;
       Name = @{ ru = 'Antigravity CLI - ИИ-агент в консоли (Google)';
                 en = 'Antigravity CLI - console AI agent (Google)' } },
    @{ Kind = 'winget'; Id = 'MoonshotAI.KimiCodeCLI'; Check = 'kimi';   Override = $null;
       Name = @{ ru = 'Kimi Code - ИИ-агент в консоли (Moonshot AI)';
                 en = 'Kimi Code - console AI agent (Moonshot AI)' } },
    @{ Kind = 'winget'; Id = 'CognitionAI.DevinCLI';   Check = 'devin';  Override = $null;
       Name = @{ ru = 'Devin CLI - ИИ-агент в консоли (Cognition)';
                 en = 'Devin CLI - console AI agent (Cognition)' } },
    @{ Kind = 'winget'; Id = 'xAI.GrokBuild';          Check = 'grok';   Override = $null;
       Name = @{ ru = 'Grok Build - ИИ-агент в консоли (xAI)';
                 en = 'Grok Build - console AI agent (xAI)' } },
    @{ Kind = 'npm'; Pkg = '@google/gemini-cli';       Check = 'gemini';
       Name = @{ ru = 'Gemini CLI - ИИ-агент в консоли (Google; нужен Node)';
                 en = 'Gemini CLI - console AI agent (Google; needs Node)' } },
    @{ Kind = 'npm'; Pkg = '@opencode/cli';            Check = 'opencode';
       Name = @{ ru = 'opencode - ИИ-агент в консоли (открытый, разные модели; нужен Node)';
                 en = 'opencode - console AI agent (open, multi-model; needs Node)' } },
    @{ Kind = 'npm'; Pkg = '@qwen-code/qwen-code';     Check = 'qwen';
       Name = @{ ru = 'Qwen Code - ИИ-агент в консоли (Alibaba Qwen; нужен Node)';
                 en = 'Qwen Code - console AI agent (Alibaba Qwen; needs Node)' } },
    @{ Kind = 'npm'; Pkg = 'droid';                    Check = 'droid';
       Name = @{ ru = 'Droid - ИИ-агент в консоли (Factory; нужен Node)';
                 en = 'Droid - console AI agent (Factory; needs Node)' } },
    @{ Kind = 'npm'; Pkg = 'cline';                    Check = 'cline';
       Name = @{ ru = 'Cline - ИИ-агент в консоли (открытый, разные модели; нужен Node)';
                 en = 'Cline - console AI agent (open, multi-model; needs Node)' } },
    @{ Kind = 'npm'; Pkg = '@augmentcode/auggie';      Check = 'auggie';
       Name = @{ ru = 'Auggie - ИИ-агент в консоли (Augment Code; нужен Node)';
                 en = 'Auggie - console AI agent (Augment Code; needs Node)' } },
    @{ Kind = 'npm'; Pkg = '@jetbrains/junie';         Check = 'junie';
       Name = @{ ru = 'Junie - ИИ-агент в консоли (JetBrains; нужен Node)';
                 en = 'Junie - console AI agent (JetBrains; needs Node)' } },
    @{ Kind = 'npm'; Pkg = '@qoder-ai/qodercli';       Check = 'qodercli';
       Name = @{ ru = 'Qoder CLI - ИИ-агент в консоли (Alibaba; нужен Node)';
                 en = 'Qoder CLI - console AI agent (Alibaba; needs Node)' } },
    @{ Kind = 'npm'; Pkg = '@tencent-ai/codebuddy-code'; Check = 'codebuddy';
       Name = @{ ru = 'CodeBuddy - ИИ-агент в консоли (Tencent; нужен Node)';
                 en = 'CodeBuddy - console AI agent (Tencent; needs Node)' } },
    @{ Kind = 'npm'; Pkg = 'codebuff';                 Check = 'codebuff';
       Name = @{ ru = 'Codebuff - ИИ-агент в консоли (открытый; нужен Node)';
                 en = 'Codebuff - console AI agent (open; needs Node)' } }
)

function Get-WingetPick($Id) {
    if (-not $script:WingetArch) { return $null }
    $rec = $script:WingetArch.PSObject.Properties["$Id"]
    if (-not $rec) { return $null }
    $pick = $rec.Value.PSObject.Properties["$script:Arch"]
    if (-not $pick) { return $null }
    return [string]$pick.Value
}

function Test-WingetUser($Id) {
    if (-not $script:WingetUser) { return $false }
    $rec = $script:WingetUser.PSObject.Properties["$Id"]
    if (-not $rec) { return $false }
    return (@($rec.Value) -contains "$script:Arch")
}

function Test-DevItemFits($Item) {
    switch ("$($Item.Kind)") {
        'winget' { return ($null -ne (Get-WingetPick $Item.Id)) }
        'npm'    { return ($null -ne (Get-WingetPick 'OpenJS.NodeJS.LTS')) }
        'wsl'    { return ($script:Arch -ne 'x86') }
    }
    if ($Item.Arch) { return (@($Item.Arch) -contains $script:Arch) }
    return $true
}

function Select-FittingItems($Items) {
    $out = @()
    $gap = $false
    foreach ($t in @($Items)) {
        if (-not $t) { continue }
        if ($t.Kind -eq 'blank') { if ($out.Count -gt 0) { $gap = $true }; continue }
        if (-not (Test-DevItemFits $t)) { continue }
        if ($gap) { $out += @{ Kind = 'blank' }; $gap = $false }
        $out += $t
    }
    return $out
}

function Get-WingetExe {
    if (Get-Command winget -ErrorAction SilentlyContinue) { return 'winget' }
    return $null
}

$script:WingetAlready = @(-1978335189, -1978335135, -1978334963, -1978334962)
$script:WingetReboot  = @(-1978334967)
$script:WingetAbsent  = @(-1978335212)

$script:DevInstalledText = ''

function Update-DevInstalled($Winget) {
    $script:DevInstalledText = ''
    $need = @($script:DevActiveItems | Where-Object { $_.Kind -eq 'winget' -and -not $_.Check })
    if ($need.Count -eq 0 -or -not $Winget) { return }
    Write-Host ("`r  " + $script:S.DevLooking) -NoNewline -ForegroundColor DarkGray
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $script:DevInstalledText = "$(& $Winget @('list', '--source', 'winget', '--accept-source-agreements', '--disable-interactivity') 2>&1 | Out-String)" }
    catch { $script:DevInstalledText = '' }
    finally { $ErrorActionPreference = $old }
    Write-Host ("`r" + (' ' * (Get-LiveWidth)) + "`r") -NoNewline
}

function Test-DevInstalled($Item) {
    if ($Item.Check -and (Get-Command $Item.Check -ErrorAction SilentlyContinue)) { return $true }
    if (-not $Item.Id -or -not $script:DevInstalledText) { return $false }
    return [bool]([regex]::IsMatch($script:DevInstalledText, '(?m)\s' + [regex]::Escape($Item.Id) + '\s'))
}

function Get-DevToolName($Item) {
    $n = $Item.Name.$($script:Lang)
    if (-not $n) { $n = $Item.Name.en }
    return $n
}

function Show-DevToolList {
    $n = 0
    foreach ($t in $script:DevActiveItems) {
        if ($t.Kind -eq 'blank') { Write-Host ''; continue }
        $n++
        $num = '{0,2}' -f $n
        $present = $false
        if ($t.Kind -eq 'wsl') {
            $wsl = Get-WslExe
            if ($wsl) { $present = [bool](Test-WslDistroPresent $wsl $script:WslDistro) }
        }
        elseif ($t.Kind -eq 'link') { Write-Host ("  [$num] [>] " + (Get-DevToolName $t)) -ForegroundColor Cyan; continue }
        elseif ($t.Kind -eq 'action') { Write-Host ("  [$num] [>] " + (Get-DevToolName $t)) -ForegroundColor Cyan; continue }
        else { $present = Test-DevInstalled $t }
        if ($present) { Write-Host ("  [$num] [+] " + (Get-DevToolName $t)) -ForegroundColor Green }
        else          { Write-Host ("  [$num] [ ] " + (Get-DevToolName $t)) }
    }
}

function Invoke-NpmGlobal($Verb, $Pkg, $Name) {
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        $winget = Get-WingetExe
        if ($Verb -ne 'install' -or -not $winget) { Add-Outcome 'warn' ($script:S.DevNeedNode -f $Name); return $null }
        Clear-Live
        if (-not (Test-Yes (Read-Host ('  ' + ($script:S.DevNodeAsk -f $Name))))) { return $null }
        Write-Live 'Node.js LTS'
        $rc = 1
        $nodeArgs = @('install', '-e', '--id', 'OpenJS.NodeJS.LTS', '--source', 'winget', '--accept-package-agreements', '--accept-source-agreements', '--silent')
        $nodePick = Get-WingetPick 'OpenJS.NodeJS.LTS'
        if ($nodePick) { $nodeArgs += @('--architecture', $nodePick) }
        if (Test-WingetUser 'OpenJS.NodeJS.LTS') { $nodeArgs += @('--scope', 'user') }
        try { $rc = Invoke-Quiet $winget $nodeArgs } catch { }
        Update-SessionPath
        if ($rc -ne 0 -or -not (Get-Command npm -ErrorAction SilentlyContinue)) { Add-Outcome 'warn' $script:S.DevNodeRestart; return $null }
    }
    $npmVerb = if ($Verb -eq 'upgrade') { 'update' } else { $Verb }
    try { return ((Invoke-Quiet 'npm' @($npmVerb, '-g', $Pkg)) -eq 0) }
    catch { return $false }
}

function Invoke-DevToolBatch($Verb, $Items, $Winget) {
    Start-Work
    $done = @(); $bad = @(); $have = @(); $reboot = @(); $opened = @(); $n = 0
    $list = @($Items)
    foreach ($t in $list) {
        if ($t.Kind -eq 'blank') { continue }
        $n++
        if ($t.Kind -eq 'action') { continue }
        $name = ((Get-DevToolName $t) -split ' - ')[0]
        if ($t.Kind -eq 'wsl') {
            Clear-Live
            if ($Verb -eq 'install') { Invoke-WslScreen } elseif ($Verb -eq 'uninstall') { Invoke-WslRevert }
            continue
        }
        if ($t.Kind -eq 'link') {
            if ($Verb -eq 'install' -and "$($t.Url)".StartsWith('https://')) {
                try { Start-Process "$($t.Url)"; $opened += (Get-DevToolName $t) } catch { $bad += $name }
            }
            continue
        }
        Write-Live ('{0} ({1} / {2})' -f $name, $n, $list.Count)
        $ok = $false
        if ($t.Kind -eq 'npm') { $ok = Invoke-NpmGlobal $Verb $t.Pkg $name }
        else {
            $a = @('uninstall', '-e', '--id', $t.Id, '--silent')
            if ($Verb -ne 'uninstall') {
                $a = @($Verb, '-e', '--id', $t.Id, '--source', 'winget', '--accept-package-agreements', '--accept-source-agreements', '--silent')
                if ($Verb -eq 'install' -and $t.Override) { $a += @('--override', $t.Override) }
                $pick = Get-WingetPick $t.Id
                if ($Verb -eq 'install' -and $pick) { $a += @('--architecture', $pick) }
                if ($Verb -eq 'install' -and -not $t.Override -and (Test-WingetUser $t.Id)) { $a += @('--scope', 'user') }
            }
            $rc = 1
            try { $rc = Invoke-Quiet $Winget $a } catch { $rc = 1 }
            $ok = ($rc -eq 0)
            if ($Verb -ne 'uninstall') {
                if ($script:WingetAlready -contains $rc) { $have += $name; continue }
                if ($script:WingetReboot -contains $rc) { $reboot += $name; continue }
                if ($Verb -eq 'upgrade' -and $script:WingetAbsent -contains $rc) { continue }
            }
        }
        if ($null -eq $ok) { continue }
        if ($ok) { $done += $name } else { $bad += $name }
    }
    $okText = $script:S.DevRemoved
    $haveText = $script:S.DevHave
    if ($Verb -eq 'install') { $okText = $script:S.DevOk }
    if ($Verb -eq 'upgrade') { $okText = $script:S.DevUpdated; $haveText = $script:S.DevFresh }
    if ($done.Count -gt 0) { Add-Outcome 'ok' ($okText -f ($done -join ', ')) }
    if ($have.Count -gt 0) { Add-Outcome 'note' ($haveText -f ($have -join ', ')) }
    if ($reboot.Count -gt 0) { Add-Outcome 'warn' ($script:S.DevReboot -f ($reboot -join ', ')) }
    if ($opened.Count -gt 0) { Add-Outcome 'note' ($script:S.DevOpened -f ($opened -join '; ')) }
    if ($bad.Count -gt 0) { Add-Outcome 'fail' ($script:S.DevFail -f ($bad -join ', ')) }
    Show-Outcome
}

function Invoke-DevToolInstall($Items, $Winget) { Invoke-DevToolBatch 'install' $Items $Winget }

function Invoke-DevToolRemove($Items, $Winget) { Invoke-DevToolBatch 'uninstall' $Items $Winget }

function Invoke-DevToolUpgrade($Items, $Winget) { Invoke-DevToolBatch 'upgrade' $Items $Winget }

function Select-DevToolItems($Answer) {
    $sel = @()
    $numbered = @($script:DevActiveItems | Where-Object { $_.Kind -ne 'blank' })
    foreach ($tok in ($Answer -split '[,\s]+' | Where-Object { $_ -ne '' })) {
        $num = 0
        if ([int]::TryParse($tok, [ref]$num) -and $num -ge 1 -and $num -le $numbered.Count) {
            $sel += $numbered[$num - 1]
        }
    }
    return $sel
}

function Invoke-DevToolsScreen($Items, $Title, $Warn) {
    $script:DevActiveItems = @(Select-FittingItems $Items)
    $winget = Get-WingetExe
    $stale = $true
    while ($true) {
        if ($stale) { Update-DevInstalled $winget; $stale = $false }
        Write-Host ''
        Write-Host ('  ' + $Title) -ForegroundColor Cyan
        Write-Host ''
        if (-not $winget -and @($script:DevActiveItems | Where-Object { $_.Kind -ne 'link' -and $_.Kind -ne 'blank' }).Count -gt 0) {
            Write-Host ('  ' + $script:S.DevNoWinget) -ForegroundColor Yellow
            Pause-Return; return
        }
        foreach ($l in $Warn) { Write-Host ('  ' + $l) -ForegroundColor DarkGray }
        Write-Host ''
        Show-DevToolList
        Write-Host ''
        Write-Host ('  ' + $script:S.DevActions)
        Write-Host ''
        $ans = (Read-Host ('  ' + $script:S.Choice)).Trim()

        if ($ans -eq '0' -or $ans -eq '') { return }
        $key = Get-Key $ans
        $stale = $true
        if ($key -eq 'u') {
            Invoke-DevToolUpgrade $script:DevActiveItems $winget; Pause-Return; continue
        }
        if ($key -eq 'a') {
            $all = @($script:DevActiveItems | Where-Object { $_.Kind -ne 'link' -and $_.Kind -ne 'action' -and $_.Kind -ne 'blank' })
            if ($all.Count -eq 0) { Write-Host ''; Write-Host ('  ' + $script:S.DevLinksOnly) -ForegroundColor Yellow; Pause-Return; continue }
            Invoke-DevToolInstall $all $winget; Pause-Return; continue
        }
        if ($key -eq 'x') {
            $rem = (Read-Host ('  ' + $script:S.DevRemoveAsk)).Trim()
            $sel = @(Select-DevToolItems $rem | Where-Object { $_.Kind -ne 'link' -and $_.Kind -ne 'action' })
            $named = @($sel | Where-Object { $_.Kind -ne 'wsl' } | ForEach-Object { Get-DevToolName $_ })
            $go = $true
            if ($named.Count -gt 0) {
                Write-Host ''
                $go = Test-Yes (Read-Host ('  ' + ($script:S.DevRemoveConfirm -f ($named -join ', '))))
            }
            if ($go -and $sel.Count -gt 0) { Invoke-DevToolRemove $sel $winget }
            Pause-Return; continue
        }
        $sel = Select-DevToolItems $ans
        if (@($sel).Count -eq 0) { Write-Host ''; Write-Host ('  ' + $script:S.BadChoice) -ForegroundColor Yellow; Pause-Return; continue }
        $acts = @($sel | Where-Object { $_.Kind -eq 'action' })
        $rest = @($sel | Where-Object { $_.Kind -ne 'action' })
        foreach ($act in $acts) { Invoke-ProgramModuleAction $act.Module $act.Action }
        if ($rest.Count -gt 0) { Invoke-DevToolInstall $rest $winget; Pause-Return }
        elseif ($acts.Count -eq 0) { Pause-Return }
    }
}
