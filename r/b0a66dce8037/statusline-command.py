#!/usr/bin/env python3
import calendar
import datetime
import json
import os
import re
import subprocess
import sys
import time

try:
    sys.stdin.reconfigure(encoding='utf-8', errors='replace')
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
except Exception:
    pass

def _read_lang():
    try:
        _p = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'statusline.lang')
        _v = open(_p, encoding='utf-8').read().strip().lower()
        if _v in ('ru', 'en'):
            return _v
    except Exception:
        pass
    return 'ru'

LANG = _read_lang()
U = {
    'ru': {'s': 'с', 'm': 'м', 'h': 'ч', 'd': 'д', '5h': '5ч', '7d': '7д'},
    'en': {'s': 's', 'm': 'm', 'h': 'h', 'd': 'd', '5h': '5h', '7d': '7d'},
}[LANG]

CTX_WARN_REMAIN = 50
CTX_CRIT_REMAIN = 20

COST_WARN = 0.30
COST_CRIT = 1.00

RL_WARN = 50
RL_CRIT = 80

SUB_ACCOUNT_FILE = os.path.expanduser('~/.claude.json')
SUB_RENEWAL_DAY = None
SUB_WARN_DAYS = 5

TWO_LINE = True

DURATION_MIN_SEC = 30

RST = '\033[0m'
DIM = '\033[2m'
BOLD = '\033[1m'
CYAN = '\033[38;2;137;220;235m'
GREEN = '\033[38;2;166;227;161m'
YELLOW = '\033[38;2;249;226;175m'
RED = '\033[38;2;243;139;168m'
WHITE = '\033[38;2;205;214;244m'
MAGENTA = '\033[38;2;203;166;247m'
BLUE = '\033[38;2;137;180;250m'
PEACH = '\033[38;2;250;179;135m'
LAVENDER = '\033[38;2;180;190;254m'

I_BOLT = ''
I_WARN = ''
I_FIRE = ''
I_FOLDER = ''
I_BRANCH = ''
I_COST = ''
I_CLOCK = ''
I_EXPAND = ''
I_STYLE = ''
I_CACHE = ''
I_AGENT = ''
I_WORKTREE = ''
UP = '↑'
DOWN = '↓'
SEP = '│'
I_PR = ''

ANSI_RE = re.compile(r'\x1b\[[0-9;]*m')

def vis_len(s):
    return len(ANSI_RE.sub('', s))

def battery_icon(remain):
    if remain <= 10:
        return '\U000F0083'
    if remain <= 30:
        return '\U000F007B'
    if remain <= 50:
        return '\U000F007D'
    if remain <= 70:
        return '\U000F007F'
    if remain <= 90:
        return '\U000F0081'
    return '\U000F0079'

def assemble(items, budget):
    items = list(items)
    sep = f" {DIM}{SEP}{RST} "
    while len(items) > 1 and budget:
        line = sep.join(t for _, t in items)
        if vis_len(line) <= budget:
            break
        worst_p = max(p for p, _ in items)
        if worst_p == 0:
            break
        idx = max(i for i, (p, _) in enumerate(items) if p == worst_p)
        items.pop(idx)
    return sep.join(t for _, t in items)

def g(obj, path, default=None):
    for k in path.split('.'):
        if not isinstance(obj, dict):
            return default
        obj = obj.get(k)
        if obj is None:
            return default
    return obj

def fmt_k(n):
    try:
        n = int(n or 0)
    except (TypeError, ValueError):
        return '0'
    if n == 0:
        return '0'
    if n >= 1_000_000:
        return f'{n / 1_000_000:.1f}M'
    if n >= 1_000:
        return f'{n // 1000}k'
    return str(n)

def fmt_dur(ms):
    s = int((ms or 0) / 1000)
    if s < 60:
        return f'{s}с'
    m, s = divmod(s, 60)
    if m < 60:
        return f'{m}м {s:02d}с' if s else f'{m}м'
    h, m = divmod(m, 60)
    return f'{h}ч {m:02d}м'

def fmt_reset(epoch):
    try:
        delta = int(epoch) - int(time.time())
    except (TypeError, ValueError):
        return ''
    if delta <= 0:
        return '0м'
    m = delta // 60
    if m < 60:
        return f'{m}м'
    h, m = divmod(m, 60)
    if h < 24:
        return f'{h}ч {m:02d}м' if m else f'{h}ч'
    d_, h = divmod(h, 24)
    return f'{d_}д {h}ч' if h else f'{d_}д'

def sub_renewal_day(path, fallback):
    try:
        with open(path, encoding='utf-8') as fh:
            m = re.search(r'"subscriptionCreatedAt"\s*:\s*"(\d{4})-(\d{2})-(\d{2})',
                          fh.read())
        if m:
            return int(m.group(3))
    except Exception:
        pass
    return fallback

def sub_renewal(day):
    today = datetime.date.today()
    if today.day < day:
        y, m = today.year, today.month
    elif today.month == 12:
        y, m = today.year + 1, 1
    else:
        y, m = today.year, today.month + 1
    nxt = datetime.date(y, m, min(day, calendar.monthrange(y, m)[1]))
    return nxt, (nxt - today).days

def build_bar(pct, width=10):
    pct = int(pct or 0)
    filled = min(width, max(0, pct * width // 100))
    empty = width - filled
    remain = 100 - pct
    if remain > CTX_WARN_REMAIN:
        clr = GREEN
    elif remain > CTX_CRIT_REMAIN:
        clr = YELLOW
    else:
        clr = RED
    icon = battery_icon(remain)
    bar = f"{clr}[{'█' * filled}{DIM}{'░' * empty}{RST}{clr}]{RST}"
    return bar, clr, icon

def git_info(cwd):
    if not cwd or not os.path.isdir(cwd):
        return None, 0, 0
    try:
        subprocess.check_output(
            ['git', '-C', cwd, 'rev-parse', '--git-dir'],
            stderr=subprocess.DEVNULL, timeout=2)
        branch = subprocess.check_output(
            ['git', '-C', cwd, 'branch', '--show-current'],
            text=True, stderr=subprocess.DEVNULL, timeout=2).strip()
        staged_out = subprocess.check_output(
            ['git', '-C', cwd, 'diff', '--cached', '--numstat'],
            text=True, stderr=subprocess.DEVNULL, timeout=2).strip()
        mod_out = subprocess.check_output(
            ['git', '-C', cwd, 'diff', '--numstat'],
            text=True, stderr=subprocess.DEVNULL, timeout=2).strip()
        staged = len([ln for ln in staged_out.split('\n') if ln])
        modified = len([ln for ln in mod_out.split('\n') if ln])
        return (branch or 'detached'), staged, modified
    except Exception:
        return None, 0, 0

def fmt_pct(pct):
    if 0 < pct < 1:
        return '<1'
    return str(int(pct))

def rl_color(pct):
    if pct >= RL_CRIT:
        return RED
    if pct >= RL_WARN:
        return YELLOW
    return GREEN

def cost_color(cost):
    if cost >= COST_CRIT:
        return RED
    if cost >= COST_WARN:
        return YELLOW
    return GREEN

try:
    d = json.load(sys.stdin)
except Exception:
    print('')
    sys.exit(0)

model = g(d, 'model.display_name', 'Claude')
cwd = g(d, 'workspace.current_dir') or g(d, 'cwd') or ''
cwd_name = os.path.basename(cwd) or cwd

used_pct = g(d, 'context_window.used_percentage')
ctx_size = g(d, 'context_window.context_window_size', 200000)
turn_in = g(d, 'context_window.current_usage.input_tokens', 0) or 0
turn_cache = g(d, 'context_window.current_usage.cache_read_input_tokens', 0) or 0
sess_in = g(d, 'context_window.total_input_tokens', 0) or 0
sess_out = g(d, 'context_window.total_output_tokens', 0) or 0

cost = float(g(d, 'cost.total_cost_usd', 0) or 0)
dur_ms = g(d, 'cost.total_duration_ms', 0) or 0

style = g(d, 'output_style.name', '') or ''
session_name = g(d, 'session_name', '') or ''
worktree = g(d, 'worktree.name') or g(d, 'workspace.git_worktree') or ''
agent_name = g(d, 'agent.name', '') or ''

rl_5h = g(d, 'rate_limits.five_hour.used_percentage')
rl_7d = g(d, 'rate_limits.seven_day.used_percentage')

effort = g(d, 'effort.level', '') or ''
thinking = bool(g(d, 'thinking.enabled', False))
pr_num = g(d, 'pr.number')
pr_state = g(d, 'pr.review_state', '') or ''
exceeds_200k = bool(g(d, 'exceeds_200k_tokens', False))
fast_mode = bool(g(d, 'fast_mode', False))

try:
    term_cols = int(os.environ.get('COLUMNS', 0) or 0)
except ValueError:
    term_cols = 0
BUDGET = max(0, term_cols - 4) if term_cols else 0

p1 = []

model_short = model.replace(' (1M context)', '').strip()
model_seg = f"{CYAN}{BOLD}{model_short}{RST}"

if int(ctx_size or 0) > 200_000:
    exp_clr = PEACH if exceeds_200k else MAGENTA
    model_seg += f" {exp_clr}{I_EXPAND}1M{RST}"
if fast_mode:
    model_seg += f" {PEACH}fast{RST}"
p1.append((0, model_seg))

if used_pct is not None:
    bar, clr, icon = build_bar(used_pct)
    p1.append((0, f"{bar} {BOLD}{clr}{int(used_pct)}%{RST} {clr}{icon}{RST}"))
else:
    p1.append((0, f"{DIM}[░░░░░░░░░░] ---%{RST}"))

branch, staged, modified = git_info(cwd)
if branch:
    g_str = f"{DIM}{I_BRANCH}{RST} {MAGENTA}{branch}{RST}"
    if staged:
        g_str += f" {GREEN}+{staged}{RST}"
    if modified:
        g_str += f" {YELLOW}~{modified}{RST}"
    p1.append((1, g_str))

if session_name:
    p1.append((3, f"{PEACH}{I_STYLE} {session_name}{RST}"))
if worktree:
    p1.append((2, f"{PEACH}{I_WORKTREE} {worktree}{RST}"))
if cwd_name:
    p1.append((2, f"{DIM}{I_FOLDER}{RST} {WHITE}{cwd_name}{RST}"))
if agent_name:
    p1.append((2, f"{LAVENDER}{I_AGENT} {agent_name}{RST}"))

if style and style not in ('default', 'Default'):
    p1.append((4, f"{DIM}{I_STYLE} {style}{RST}"))

line1 = assemble(p1, BUDGET)

p2 = []

if cost > 0:
    c = cost_color(cost)
    cost_str = f"{cost:.2f}" if cost >= 0.01 else f"{cost:.3f}"
    p2.append((1, f"{c}{I_COST}{cost_str}{RST}"))

turn_parts = [f"{WHITE}{fmt_k(turn_in)}{RST}"]
if turn_cache > 0:
    turn_parts.append(f"{DIM}{I_CACHE}{fmt_k(turn_cache)}{RST}")
p2.append((4, f"{DIM}turn{RST} " + ' '.join(turn_parts)))

p2.append((4, f"{DIM}sess{RST} {UP}{fmt_k(sess_in)} {DOWN}{fmt_k(sess_out)}"))

if rl_5h is not None or rl_7d is not None:
    rl_parts = []
    if rl_5h is not None:
        seg = f"{rl_color(rl_5h)}5ч:{fmt_pct(rl_5h)}%{RST}"
        r = fmt_reset(g(d, 'rate_limits.five_hour.resets_at'))
        if r:
            seg += f"{DIM}·{r}{RST}"
        rl_parts.append(seg)
    if rl_7d is not None:
        seg = f"{rl_color(rl_7d)}7д:{fmt_pct(rl_7d)}%{RST}"
        r = fmt_reset(g(d, 'rate_limits.seven_day.resets_at'))
        if r:
            seg += f"{DIM}·{r}{RST}"
        rl_parts.append(seg)
    p2.append((0, ' '.join(rl_parts)))

sub_day = sub_renewal_day(SUB_ACCOUNT_FILE, SUB_RENEWAL_DAY)
if sub_day:
    nxt, days_left = sub_renewal(sub_day)
    if days_left <= 1:
        sub_clr = RED
    elif days_left <= SUB_WARN_DAYS:
        sub_clr = YELLOW
    else:
        sub_clr = WHITE
    p2.append((2, f"{DIM}sub{RST} {sub_clr}{nxt.strftime('%d.%m')}{RST}{DIM}·{days_left}д{RST}"))

if effort:
    eff_seg = f"{DIM}eff{RST} {LAVENDER}{effort}{RST}"
    if thinking:
        eff_seg += f"{MAGENTA}·think{RST}"
    p2.append((3, eff_seg))
elif thinking:
    p2.append((3, f"{MAGENTA}think{RST}"))

if pr_num:
    pr_clr, pr_abbr = {
        'approved': (GREEN, 'appr'),
        'changes_requested': (RED, 'chg'),
        'pending': (YELLOW, 'pend'),
        'draft': (DIM, 'draft'),
    }.get(pr_state, (WHITE, ''))
    pr_seg = f"{DIM}{I_PR}{RST} {pr_clr}#{pr_num}{RST}"
    if pr_abbr:
        pr_seg += f" {pr_clr}{pr_abbr}{RST}"
    p2.append((2, pr_seg))

if int(dur_ms / 1000) >= DURATION_MIN_SEC:
    p2.append((5, f"{DIM}{I_CLOCK}{fmt_dur(dur_ms)}{RST}"))

line2 = assemble(p2, max(0, BUDGET - 2)) if p2 else ''

print(line1)
if TWO_LINE and line2:
    print(f"{DIM}{SEP}{RST} {line2}")
elif line2:
    print(f"{DIM}  ·  {RST}{line2}")
