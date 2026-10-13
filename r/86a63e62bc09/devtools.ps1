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
        if ($Verb -ne 'install' -or -not $winget) {
            Write-Host ('  ' + ($script:S.DevNeedNode -f $Name)) -ForegroundColor Yellow
            return
        }
        if (-not (Test-Yes (Read-Host ('  ' + ($script:S.DevNodeAsk -f $Name))))) { return }
        Write-Host ('  ' + ($script:S.DevInstalling -f 'Node.js LTS'))
        $rc = 1
        try { $rc = Invoke-Quiet $winget @('install', '-e', '--id', 'OpenJS.NodeJS.LTS', '--accept-package-agreements', '--accept-source-agreements', '--silent') } catch { }
        Update-SessionPath
        if ($rc -ne 0 -or -not (Get-Command npm -ErrorAction SilentlyContinue)) {
            Write-Host ('  ' + $script:S.DevNodeRestart) -ForegroundColor Yellow
            return
        }
    }
    $key = if ($Verb -eq 'install') { $script:S.DevInstalling } else { $script:S.DevRemoving }
    Write-Host ('  ' + ($key -f $Name))
    try {
        $rc = Invoke-Quiet 'npm' @($Verb, '-g', $Pkg)
        if ($rc -eq 0) {
            $ok = if ($Verb -eq 'install') { $script:S.DevOk } else { $script:S.DevRemoved }
            Write-Host ('  ' + ($ok -f $Name)) -ForegroundColor Green
        }
        else { Write-Host ('  ' + ($script:S.DevFail -f $Name)) -ForegroundColor Yellow }
    }
    catch { Write-Host ('  ' + ($script:S.DevFail -f $Name)) -ForegroundColor Yellow }
}

function Invoke-DevToolInstall($Items, $Winget) {
    foreach ($t in $Items) {
        if ($t.Kind -eq 'wsl') { Invoke-WslScreen; continue }
        if ($t.Kind -eq 'npm') { Write-Host ''; Invoke-NpmGlobal 'install' $t.Pkg (Get-DevToolName $t); continue }
        Write-Host ''
        Write-Host ('  ' + ($script:S.DevInstalling -f (Get-DevToolName $t)))
        $a = @('install', '-e', '--id', $t.Id, '--accept-package-agreements', '--accept-source-agreements', '--silent')
        if ($t.Override) { $a += @('--override', $t.Override) }
        try {
            $rc = Invoke-Quiet $Winget $a
            if ($rc -eq 0) { Write-Host ('  ' + ($script:S.DevOk -f (Get-DevToolName $t))) -ForegroundColor Green }
            else { Write-Host ('  ' + ($script:S.DevFail -f (Get-DevToolName $t))) -ForegroundColor Yellow }
        }
        catch { Write-Host ('  ' + ($script:S.DevFail -f (Get-DevToolName $t))) -ForegroundColor Yellow }
    }
}

function Invoke-DevToolRemove($Items, $Winget) {
    foreach ($t in $Items) {
        if ($t.Kind -eq 'wsl') { Invoke-WslRevert; continue }
        if ($t.Kind -eq 'npm') { Write-Host ''; Invoke-NpmGlobal 'uninstall' $t.Pkg (Get-DevToolName $t); continue }
        Write-Host ''
        Write-Host ('  ' + ($script:S.DevRemoving -f (Get-DevToolName $t)))
        try {
            $rc = Invoke-Quiet $Winget @('uninstall', '-e', '--id', $t.Id, '--silent')
            if ($rc -eq 0) { Write-Host ('  ' + ($script:S.DevRemoved -f (Get-DevToolName $t))) -ForegroundColor Green }
            else { Write-Host ('  ' + ($script:S.DevFail -f (Get-DevToolName $t))) -ForegroundColor Yellow }
        }
        catch { Write-Host ('  ' + ($script:S.DevFail -f (Get-DevToolName $t))) -ForegroundColor Yellow }
    }
}

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
