#!/usr/bin/env python3
import calendar
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
OMP_CONFIG = os.path.join(HERE, 'claude.omp.json')
LEGACY = os.path.join(HERE, 'statusline-command.py')

def _read_lang():
    try:
        v = open(os.path.join(HERE, 'statusline.lang'), encoding='utf-8').read().strip().lower()
        if v in ('ru', 'en'):
            return v
    except Exception:
        pass
    return 'ru'

LANG = _read_lang()
U = {
    'ru': {'s': 'с', 'm': 'м', 'h': 'ч', 'd': 'д', '5h': '5ч', '7d': '7д'},
    'en': {'s': 's', 'm': 'm', 'h': 'h', 'd': 'd', '5h': '5h', '7d': '7d'},
}[LANG]

SUB_ACCOUNT_FILE = os.path.expanduser('~/.claude.json')
SUB_RENEWAL_DAY = None
SUB_WARN_DAYS = 5

DURATION_MIN_SEC = 30

WIDTH_MARGIN = 4
BOTTOM_GAP = 1
ROW_GAP = 0
FRAME = '\033[38;2;33;199;199m│\033[0m'
BLANK = '⠀'
MAX_DROP = 5

OMP_TIMEOUT = 5

ANSI_RE = re.compile(r'\x1b\[[0-9;]*m|\x1b\]8;[^\x1b\x07]*(?:\x1b\\|\x07)')

def vis_len(s):
    return len(ANSI_RE.sub('', s))

def g(obj, path, default=None):
    for k in path.split('.'):
        if not isinstance(obj, dict):
            return default
        obj = obj.get(k)
        if obj is None:
            return default
    return obj

def fmt_dur(ms):
    s = int((ms or 0) / 1000)
    if s < 60:
        return f"{s}{U['s']}"
    m, s = divmod(s, 60)
    if m < 60:
        return f"{m}{U['m']} {s:02d}{U['s']}" if s else f"{m}{U['m']}"
    h, m = divmod(m, 60)
    return f"{h}{U['h']} {m:02d}{U['m']}"

def fmt_reset(epoch):
    try:
        delta = int(epoch) - int(time.time())
    except (TypeError, ValueError):
        return ''
    if delta <= 0:
        return f"0{U['m']}"
    m = delta // 60
    if m < 60:
        return f"{m}{U['m']}"
    h, m = divmod(m, 60)
    if h < 24:
        return f"{h}{U['h']} {m:02d}{U['m']}" if m else f"{h}{U['h']}"
    d_, h = divmod(h, 24)
    return f"{d_}{U['d']} {h}{U['h']}" if h else f"{d_}{U['d']}"

def fmt_pct(pct):
    if 0 < pct < 1:
        return '<1'
    return str(int(pct))

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

def find_omp():
    exe = shutil.which('oh-my-posh')
    if exe:
        return exe
    alias = os.path.join(os.environ.get('LOCALAPPDATA', ''),
                         'Microsoft', 'WindowsApps', 'oh-my-posh.exe')
    return alias if os.path.exists(alias) else None

def render(omp, raw, env, drop1, drop2):
    env = dict(env, CL_L1=str(drop1), CL_L2=str(drop2))
    out = subprocess.run([omp, 'claude', '--config', OMP_CONFIG],
                         input=raw, stdout=subprocess.PIPE,
                         stderr=subprocess.DEVNULL, env=env,
                         timeout=OMP_TIMEOUT).stdout
    return out.decode('utf-8', errors='replace')

def legacy(raw):
    try:
        out = subprocess.run([sys.executable, LEGACY], input=raw,
                             stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                             timeout=OMP_TIMEOUT).stdout
        sys.stdout.buffer.write(out)
    except Exception:
        pass

raw = sys.stdin.buffer.read()
try:
    d = json.loads(raw.decode('utf-8', errors='replace'))
except Exception:
    print('')
    sys.exit(0)

env = dict(os.environ)
env['CL_5H_LABEL'] = U['5h']
env['CL_7D_LABEL'] = U['7d']
env['CL_SUB_UNIT'] = U['d']

rl_5h = g(d, 'rate_limits.five_hour.used_percentage')
rl_7d = g(d, 'rate_limits.seven_day.used_percentage')
if rl_5h is not None:
    env['CL_5H_PCT'] = fmt_pct(rl_5h)
    env['CL_5H_IN'] = fmt_reset(g(d, 'rate_limits.five_hour.resets_at'))
if rl_7d is not None:
    env['CL_7D_PCT'] = fmt_pct(rl_7d)
    env['CL_7D_IN'] = fmt_reset(g(d, 'rate_limits.seven_day.resets_at'))

sub_day = sub_renewal_day(SUB_ACCOUNT_FILE, SUB_RENEWAL_DAY)
if sub_day:
    nxt, days_left = sub_renewal(sub_day)
    env['CL_SUB'] = nxt.strftime('%d.%m')
    env['CL_SUB_DAYS'] = str(days_left)
    env['CL_SUB_LVL'] = ('crit' if days_left <= 1
                         else 'warn' if days_left <= SUB_WARN_DAYS else '')

dur_ms = g(d, 'cost.total_duration_ms', 0) or 0
if int(dur_ms / 1000) >= DURATION_MIN_SEC:
    env['CL_DUR'] = fmt_dur(dur_ms)

hit = g(d, 'prompt_cache.hit_ratio')
if hit is not None and g(d, 'prompt_cache.caching_observed', True):
    cache_seg = f'{int(float(hit) * 100)}%'
    if g(d, 'prompt_cache.warm', False):
        left = fmt_reset(g(d, 'prompt_cache.expires_at'))
        if left:
            cache_seg += f' ·{left}'
    else:
        cache_seg += ' cold'
    env['CL_CACHE'] = cache_seg

try:
    term_cols = int(os.environ.get('COLUMNS', 0) or 0)
except ValueError:
    term_cols = 0
budget = max(0, term_cols - WIDTH_MARGIN) if term_cols else 0

omp = find_omp()
if not omp or not os.path.exists(OMP_CONFIG):
    legacy(raw)
    sys.exit(0)

try:
    drop = [0, 0]
    while True:
        text = render(omp, raw, env, *drop)
        if not budget:
            break
        lines = text.split('\n')
        over = [i for i in range(min(2, len(lines)))
                if vis_len(lines[i]) > budget and drop[i] < MAX_DROP]
        if not over:
            break
        for i in over:
            drop[i] += 1
except Exception:
    text = ''

if not text.strip():
    legacy(raw)
    sys.exit(0)

rows = text.rstrip('\n').split('\n')
if ROW_GAP and len(rows) > 1:
    rows[1:1] = [FRAME] * ROW_GAP
text = '\n'.join(rows + [BLANK] * BOTTOM_GAP)
sys.stdout.buffer.write(text.encode('utf-8'))
