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
    @{ Kind = 'npm'; Pkg = '@google/gemini-cli';       Check = 'gemini';
       Name = @{ ru = 'Gemini CLI - ИИ-агент в консоли (Google; нужен Node)';
                 en = 'Gemini CLI - console AI agent (Google; needs Node)' } },
    @{ Kind = 'npm'; Pkg = 'opencode-ai';              Check = 'opencode';
       Name = @{ ru = 'opencode - ИИ-агент в консоли (открытый, разные модели; нужен Node)';
                 en = 'opencode - console AI agent (open, multi-model; needs Node)' } },
    @{ Kind = 'npm'; Pkg = '@qwen-code/qwen-code';     Check = 'qwen';
       Name = @{ ru = 'Qwen Code - ИИ-агент в консоли (Alibaba Qwen; нужен Node)';
                 en = 'Qwen Code - console AI agent (Alibaba Qwen; needs Node)' } }
)

function Get-WingetExe {
    if (Get-Command winget -ErrorAction SilentlyContinue) { return 'winget' }
    return $null
}

function Get-DevToolName($Item) {
    $n = $Item.Name.$($script:Lang)
    if (-not $n) { $n = $Item.Name.en }
    return $n
}

function Show-DevToolList {
    $n = 0
    foreach ($t in $script:DevActiveItems) {
        $n++
        $num = '{0,2}' -f $n
        $present = $false
        if ($t.Kind -eq 'wsl') {
            $wsl = Get-WslExe
            if ($wsl) { $present = [bool](Test-WslDistroPresent $wsl $script:WslDistro) }
        }
        elseif ($t.Check) { $present = [bool](Get-Command $t.Check -ErrorAction SilentlyContinue) }
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
        try { $rc = Invoke-Quiet $winget @('install', '-e', '--id', 'OpenJS.NodeJS.LTS', '--accept-package-agreements', '--accept-source-agreements', '--silent') } catch { }
        Update-SessionPath
        if ($rc -ne 0 -or -not (Get-Command npm -ErrorAction SilentlyContinue)) { Add-Outcome 'warn' $script:S.DevNodeRestart; return $null }
    }
    try { return ((Invoke-Quiet 'npm' @($Verb, '-g', $Pkg)) -eq 0) }
    catch { return $false }
}

function Invoke-DevToolBatch($Verb, $Items, $Winget) {
    Start-Work
    $done = @(); $bad = @(); $n = 0
    $list = @($Items)
    foreach ($t in $list) {
        $n++
        $name = ((Get-DevToolName $t) -split ' - ')[0]
        if ($t.Kind -eq 'wsl') {
            Clear-Live
            if ($Verb -eq 'install') { Invoke-WslScreen } else { Invoke-WslRevert }
            continue
        }
        Write-Live ('{0} ({1} / {2})' -f $name, $n, $list.Count)
        $ok = $false
        if ($t.Kind -eq 'npm') { $ok = Invoke-NpmGlobal $Verb $t.Pkg $name }
        else {
            $a = @('uninstall', '-e', '--id', $t.Id, '--silent')
            if ($Verb -eq 'install') {
                $a = @('install', '-e', '--id', $t.Id, '--accept-package-agreements', '--accept-source-agreements', '--silent')
                if ($t.Override) { $a += @('--override', $t.Override) }
            }
            try { $ok = ((Invoke-Quiet $Winget $a) -eq 0) } catch { $ok = $false }
        }
        if ($null -eq $ok) { continue }
        if ($ok) { $done += $name } else { $bad += $name }
    }
    $okText = if ($Verb -eq 'install') { $script:S.DevOk } else { $script:S.DevRemoved }
    if ($done.Count -gt 0) { Add-Outcome 'ok' ($okText -f ($done -join ', ')) }
    if ($bad.Count -gt 0) { Add-Outcome 'fail' ($script:S.DevFail -f ($bad -join ', ')) }
    Show-Outcome
}

function Invoke-DevToolInstall($Items, $Winget) { Invoke-DevToolBatch 'install' $Items $Winget }

function Invoke-DevToolRemove($Items, $Winget) { Invoke-DevToolBatch 'uninstall' $Items $Winget }

function Select-DevToolItems($Answer) {
    $sel = @()
    foreach ($tok in ($Answer -split '[,\s]+' | Where-Object { $_ -ne '' })) {
        $num = 0
        if ([int]::TryParse($tok, [ref]$num) -and $num -ge 1 -and $num -le $script:DevActiveItems.Count) {
            $sel += $script:DevActiveItems[$num - 1]
        }
    }
    return $sel
}

function Invoke-DevToolsScreen($Items, $Title, $Warn) {
    $script:DevActiveItems = @($Items)
    $winget = Get-WingetExe
    while ($true) {
        Write-Host ''
        Write-Host ('  ' + $Title) -ForegroundColor Cyan
        Write-Host ''
        if (-not $winget) {
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
        if ($key -eq 'a') {
            Invoke-DevToolInstall $script:DevActiveItems $winget; Pause-Return; continue
        }
        if ($key -eq 'x') {
            $rem = (Read-Host ('  ' + $script:S.DevRemoveAsk)).Trim()
            $sel = @(Select-DevToolItems $rem)
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
        Invoke-DevToolInstall $sel $winget
        Pause-Return
    }
}
