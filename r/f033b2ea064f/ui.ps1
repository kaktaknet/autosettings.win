function Esc-Seq($body) { return ([string][char]27) + '[' + $body }

$script:Pal = @{
    Plate1 = @(43, 36, 64); Plate2 = @(58, 49, 86); Plate3 = @(74, 63, 107)
    Text   = @(217, 211, 232); Accent = @(185, 167, 230); Dim = @(120, 112, 140)
}

function Vt-Fg($rgb)  { return (Esc-Seq ('38;2;{0};{1};{2}m' -f $rgb[0], $rgb[1], $rgb[2])) }
function Vt-Bg($rgb)  { return (Esc-Seq ('48;2;{0};{1};{2}m' -f $rgb[0], $rgb[1], $rgb[2])) }
$script:VtReset = (Esc-Seq '0m')

function Get-UiCaps($Build) {
    $vt = [bool]$env:WT_SESSION
    $box = ($Build -ge 10240)
    $glyphs = $false
    try {
        $face = (Get-ItemProperty 'HKCU:\Console' -Name FaceName -ErrorAction SilentlyContinue).FaceName
        if ($face -and ($face -match 'Nerd|NF|JetBrains')) { $glyphs = $true }
    }
    catch {}
    return @{ Vt = $vt; Box = $box; Glyphs = ($glyphs -and $box) }
}

function Ui-Box {
    if ($script:Ui.Box) { return @{ TL = '╭'; TR = '╮'; BL = '╰'; BR = '╯'; H = '─'; V = '│' } }
    return @{ TL = '+'; TR = '+'; BL = '+'; BR = '+'; H = '-'; V = '|' }
}

function Get-Glyph($key) {
    if (-not $script:Ui.Box) { return '' }
    switch ($key) {
        'telemetry'   { return '▦' }
        'input'       { return '◎' }
        'ads'         { return '◆' }
        'ai'          { return '✦' }
        'apps'        { return '▣' }
        'preset'      { return '◈' }
        'yandex-net'  { return '◉' }
        'terminal'    { return '▸' }
        'ai-terminal' { return '✧' }
        'ai-agents'   { return '◇' }
        'wsl'         { return '◧' }
        'devtools'    { return '▤' }
        'certs'       { return '▦' }
        'lang'        { return '⌂' }
        'exit'        { return '×' }
        default       { return '•' }
    }
}

function Write-Plate($lines) {
    $box = Ui-Box
    $w = 0
    foreach ($l in $lines) { if ($l.Length -gt $w) { $w = $l.Length } }
    $w += 2
    $top = '  ' + $box.TL + ($box.H * ($w + 1)) + $box.TR
    $bot = '  ' + $box.BL + ($box.H * ($w + 1)) + $box.BR

    if ($script:Ui.Vt) {
        $plates = @($script:Pal.Plate1, $script:Pal.Plate2, $script:Pal.Plate3)
        $fg = Vt-Fg $script:Pal.Text
        Write-Host ('  ' + (Vt-Fg $script:Pal.Plate3) + $box.TL + ($box.H * ($w + 1)) + $box.TR + $script:VtReset)
        $i = 0
        foreach ($l in $lines) {
            $bg = Vt-Bg $plates[[Math]::Min($i, 2)]
            $pad = $l.PadRight($w)
            Write-Host ('  ' + (Vt-Fg $script:Pal.Plate3) + $box.V + $bg + $fg + ' ' + $pad + $script:VtReset + (Vt-Fg $script:Pal.Plate3) + $box.V + $script:VtReset)
            $i++
        }
        Write-Host ('  ' + (Vt-Fg $script:Pal.Plate3) + $box.BL + ($box.H * ($w + 1)) + $box.BR + $script:VtReset)
        return
    }

    Write-Host $top -ForegroundColor DarkMagenta
    $i = 0
    foreach ($l in $lines) {
        $color = if ($i -eq 0) { 'Magenta' } else { 'Gray' }
        Write-Host ('  ' + $box.V + ' ' + $l.PadRight($w) + $box.V) -ForegroundColor $color
        $i++
    }
    Write-Host $bot -ForegroundColor DarkMagenta
}

function Write-Section($text) {
    if ($script:Ui.Vt) { Write-Host ('   ' + (Vt-Fg $script:Pal.Accent) + $text + $script:VtReset) }
    else { Write-Host ('   ' + $text) -ForegroundColor Cyan }
}

function Write-Item($num, $glyphKey, $text, $available) {
    $g = Get-Glyph $glyphKey
    $lead = ('    [{0}] ' -f $num)
    if ($g) { $lead += ($g + ' ') }
    if (-not $available) {
        if ($script:Ui.Vt) { Write-Host ((Vt-Fg $script:Pal.Dim) + $lead + $text + $script:VtReset) }
        else { Write-Host ($lead + $text) -ForegroundColor DarkGray }
        return
    }
    Write-Host $lead -NoNewline
    if ($script:Ui.Vt) { Write-Host ((Vt-Fg $script:Pal.Text) + $text + $script:VtReset) }
    else { Write-Host $text }
}

function Write-Entry($label, $glyphKey, $text, $count, $desc, $available) {
    $g = Get-Glyph $glyphKey
    $lead = ('    {0,-4} ' -f $label)
    if ($g) { $lead += ($g + ' ') }
    $width = 80
    try { if ($Host.UI.RawUI.WindowSize.Width -gt 0) { $width = [int]$Host.UI.RawUI.WindowSize.Width } } catch { }
    $body = "$text".PadRight(38)
    $room = $width - $lead.Length - $body.Length - 3
    $show = ''
    $full = "$count"
    if ($count -and $desc) { $full = "$count" + ' · ' + "$desc" } elseif ($desc) { $full = "$desc" }
    foreach ($tail in @($full, "$count")) {
        if ($tail -and $tail.Length -le $room) { $show = '  ' + $tail; break }
    }
    if (-not $available) {
        if ($script:Ui.Vt) { Write-Host ((Vt-Fg $script:Pal.Dim) + $lead + $text + $script:VtReset) }
        else { Write-Host ($lead + $text) -ForegroundColor DarkGray }
        return
    }
    if (-not $show) { $body = "$text" }
    Write-Host $lead -NoNewline
    if ($script:Ui.Vt) {
        Write-Host ((Vt-Fg $script:Pal.Text) + $body + $script:VtReset + (Vt-Fg $script:Pal.Dim) + $show + $script:VtReset)
    }
    else {
        Write-Host $body -NoNewline
        Write-Host $show -ForegroundColor DarkGray
    }
}

function Write-Rule {
    $box = Ui-Box
    if ($script:Ui.Vt) { Write-Host ('   ' + (Vt-Fg $script:Pal.Dim) + ($box.H * 48) + $script:VtReset) }
    else { Write-Host ('   ' + ($box.H * 48)) -ForegroundColor DarkGray }
}

function Write-Dim($text) {
    if ($script:Ui.Vt) { Write-Host ('   ' + (Vt-Fg $script:Pal.Dim) + $text + $script:VtReset) }
    else { Write-Host ('   ' + $text) -ForegroundColor DarkGray }
}

function Test-ModernTerminal { return [bool]$env:WT_SESSION }

function Test-WtInstalled {
    if (Test-ModernTerminal) { return $true }
    return [bool](Get-Command 'wt.exe' -ErrorAction SilentlyContinue)
}

function Install-WindowsTerminal {
    return ((Invoke-Quiet 'winget' @('install', '-e', '--id', 'Microsoft.WindowsTerminal', '--source', 'winget', '--silent', '--accept-package-agreements', '--accept-source-agreements')) -eq 0)
}
