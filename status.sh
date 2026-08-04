#!/usr/bin/env bash
# Build status for the study app, reported against the weekly timetable:
# which timetable slot is built, which is still a placeholder, and how the
# student is actually scoring. Derived from the filesystem, index.html and
# progress.json, so it is always current — no hand-maintained tables.
#
#   ./status.sh             summary table for all weeks
#   ./status.sh 3           week 3, slot by slot in timetable order
#   ./status.sh 3 --all     same, plus each slot's focus line
#   ./status.sh 3 --pending just what is still missing, as a build worklist
#   ./status.sh --pending   the same worklist for every started week
#   ./status.sh today       today's session only
#   ./status.sh --check     audit: timetable vs DAY_SUBJECTS_MAP vs page ids
set -euo pipefail
cd "$(dirname "$0")"
exec python3 - "$@" <<'PY'
import json, re, sys, os, glob, datetime

args     = sys.argv[1:]
week     = next((a for a in args if a.isdigit()), None)
show_all = '--all' in args
do_check = '--check' in args
do_today = 'today' in args
do_pend  = '--pending' in args or '--todo' in args

# ---------------------------------------------------------------- timetable
# The student's fixed weekly timetable (see CLAUDE.md). Each slot carries the
# subject id it scores under. Some slots deliberately share an id: Wednesday's
# map revision warms up Geography, and the Saturday physics/biology quizzes
# both score as `pq`.
S = lambda t, icon, name, focus, sid, block='': dict(
        time=t, icon=icon, name=name, focus=focus, id=sid, block=block)

TIMETABLE = {
 'monday': [
    S('6:00–6:15', '➗',  'Maths Quick Practice',      'Tables/Fractions/Mental', 'm'),
    S('6:15–7:00', '🗣️',  'Kannada Literature',        'Reading/Vocab/Oral',      'k'),
    S('7:10–7:50', '📖',  'English Literature',        'Reading & Summary',       'e')],
 'tuesday': [
    S('6:00–6:15', '➗',  'Maths Quick Practice',      '3–5 Problems',            'm'),
    S('6:15–7:00', '⚡',  'Physics',                   'Concepts & Numericals',   'p'),
    S('7:10–7:50', '💻',  'Computer Science / Python', 'Coding & Logic',          'c')],
 'wednesday': [
    S('6:00–6:15', '🌍',  'Map Revision',              'Geography Recall',        'g'),
    S('6:15–7:00', '🌍',  'Geography',                 'Maps/Climate/Landforms',  'g'),
    S('7:10–7:50', '✍️',  'English Grammar & Writing', 'Composition & Grammar',   'e')],
 'thursday': [
    S('6:00–6:15', '➗',  'Maths Formula Recall',      'Mental Practice',         'm'),
    S('6:15–7:00', '⚗️',  'Chemistry',                 'Concepts & Definitions',  'ch'),
    S('7:10–7:50', '🇫🇷', 'French',                    'Grammar & Vocabulary',    'f')],
 'friday': [
    S('6:00–6:15', '🧬',  'Science Diagram Recall',    'Biology Keywords',        's'),
    S('6:15–7:00', '🗣️',  'Kannada Grammar & Writing', 'Grammar & Composition',   'k'),
    S('7:10–7:50', '🧬',  'Biology',                   'Diagrams & Concepts',     'b')],
 'saturday': [
    S('10:00–10:45', '➗',  'Maths Problem Solving',   'Weekly Practice',         'm',  'Morning'),
    S('11:00–11:45', '🏛️',  'History & Civics',        'Timelines & Civics',      'h',  'Morning'),
    S('2:30–3:00',   '⚡',  'Physics Quiz',            'Recall & Numericals',     'pq', 'Afternoon'),
    S('3:00–3:30',   '⚗️',  'Chemistry Quiz',          'Definitions & Concepts',  'ch', 'Afternoon'),
    S('3:40–4:10',   '🧬',  'Biology Quiz',            'Diagrams & Labelling',    'pq', 'Afternoon')],
 'sunday': [
    S('10:00–10:30', '🗣️',  'Kannada',                 'Reading & Writing',       'k',  'Morning'),
    S('10:30–11:00', '🇫🇷', 'French',                  'Vocabulary & Sentences',  'f',  'Morning'),
    S('11:15–12:00', '🌍',  'Geography + History',     'Maps/Timelines/Key Terms','gh', 'Morning'),
    S('2:30–4:00',   '🧠',  'Mixed Quiz Day',          'Whole-week recall',       'mx', 'Afternoon')],
}
ORDER = ['monday','tuesday','wednesday','thursday','friday','saturday','sunday']
SHORT = {'monday':'mon','tuesday':'tue','wednesday':'wed','thursday':'thu',
         'friday':'fri','saturday':'sat','sunday':'sun'}

# ---------------------------------------------------------------- app data
src   = open('index.html').read()
DAYS  = json.loads(re.search(r'var DAY_SUBJECTS_MAP=(\{.*?\});', src, re.S).group(1))
WEEKS = {w['num']: w for w in
         json.loads(re.search(r'var WEEKS=(\[.*?\]);', src, re.S).group(1))}
LABEL = {s['id']: s['label'] for day in DAYS.values() for s in day}

scores = {}
if os.path.exists('progress.json'):
    try:
        scores = json.load(open('progress.json')).get('scores', {})
    except Exception:
        pass

def page(wk, day):
    return 'weeks/week%02d/%s.html' % (wk, day)

def built_ids(path):
    """Subject ids a page actually scores. Most tabs use the shared quiz()
    engine, but a page may score a subject another way (the Monday maths
    warm-up takes typed answers), so the page's own SUBJECTS declaration
    counts too — that is what drives its progress pills."""
    if not os.path.exists(path):
        return set()
    src = open(path).read()
    ids = set(re.findall(r"quiz\(\s*'([a-z]+)'", src))
    m = re.search(r'var SUBJECTS\s*=\s*(\[.*?\]);', src, re.S)
    if m:
        try:
            ids |= {s['id'] for s in json.loads(m.group(1))}
        except Exception:
            pass
    return ids

def locked(path):
    """A placeholder day: nothing on it scores anything."""
    if not os.path.exists(path):
        return False
    src = open(path).read()
    return 'quiz(' not in src and 'var SUBJECTS' not in src

def score_of(wk, day, sid):
    return scores.get('icse_w%02d_%s_%s' % (wk, SHORT[day], sid))

def slot_status(wk, day, sid, have):
    """Human-readable state of one timetable slot."""
    if sid not in have:
        return 'pending'
    d = score_of(wk, day, sid)
    if not d or not d.get('totalQ'):
        return 'built · not attempted'
    pct = round(d['bestScore'] / d['totalQ'] * 100)
    return 'built · %d/%d (%d%%) %s' % (d['bestScore'], d['totalQ'], pct,
                                        '✔' if pct >= 60 else '✗')

def ids_of(day):
    """Unique subject ids the timetable expects for a day, in slot order."""
    out = []
    for s in TIMETABLE[day]:
        if s['id'] not in out:
            out.append(s['id'])
    return out

# ------------------------------------------------------- emoji-safe padding
def width(s):
    """Display columns, counting emoji as 2. Terminals render dingbats such as
    ➗ and ⚗️ double-width even though Unicode calls them narrow."""
    import unicodedata
    w = 0
    for i, ch in enumerate(s):
        o = ord(ch)
        if o in (0xFE0F, 0xFE0E, 0x200D):         # variation selector / ZWJ
            continue
        nxt = ord(s[i + 1]) if i + 1 < len(s) else 0
        if 0x1F1E6 <= o <= 0x1F1FF:               # regional indicator (flags)
            w += 1
        elif (o >= 0x1F300 or nxt == 0xFE0F
              or 0x2600 <= o <= 0x27BF            # misc symbols + dingbats
              or unicodedata.east_asian_width(ch) in 'WF'):
            w += 2
        else:
            w += 1
    return w

def pad(s, n):
    return s + ' ' * max(1, n - width(s))

# ---------------------------------------------------------------- rendering
def print_day(wk, day, date=None, indent='  '):
    path, have = page(wk, day), built_ids(page(wk, day))
    want  = ids_of(day)
    b     = sum(1 for i in want if i in have)
    head  = '%s%s' % (day.title(), ' · %s' % date.strftime('%d %b') if date else '')
    flag  = '   🔒 placeholder' if locked(path) else ('' if os.path.exists(path) else '   ⚠ file missing')
    print('%s%s%s%d/%d built%s' % (indent, pad(head, 22), '  ', b, len(want), flag))
    block = None
    for s in TIMETABLE[day]:
        if s['block'] and s['block'] != block:
            block = s['block']
            print('%s    — %s —' % (indent, block))
        shared = sum(1 for x in TIMETABLE[day] if x['id'] == s['id']) > 1
        print('%s    %s%s%s%s%s' % (
            indent,
            pad(s['time'], 13),
            pad('%s %s' % (s['icon'], s['name']), 30),
            pad(s['id'], 5),
            slot_status(wk, day, s['id'], have),
            '  (shares id)' if shared else ''))
        if show_all:
            print('%s    %s%s' % (indent, ' ' * 13, s['focus']))
    return b, len(want)

def week_totals(wk):
    b = t = 0
    for day in ORDER:
        have = built_ids(page(wk, day))
        want = ids_of(day)
        b += sum(1 for i in want if i in have)
        t += len(want)
    return b, t

def pending_slots(wk):
    """Missing subjects for a week, in timetable order. Slots that share an id
    merge into one row, so `g` reads 'Map Revision + Geography' — one quiz has
    to cover both."""
    out = []
    for day in ORDER:
        have = built_ids(page(wk, day))
        for sid in ids_of(day):
            if sid in have:
                continue
            group = [s for s in TIMETABLE[day] if s['id'] == sid]
            out.append((day, dict(
                id=sid, icon=group[0]['icon'], time=group[0]['time'],
                name=' + '.join(dict.fromkeys(s['name'] for s in group)))))
    return out

def print_pending(wk, indent='  '):
    """A build worklist: what is missing, split by how much work it is."""
    todo = pending_slots(wk)
    b, t = week_totals(wk)
    print('Week %d of 41 · %d/%d built · %d pending\n' % (wk, b, t, len(todo)))
    if not todo:
        print('%s✅ Nothing pending — all %d slots built.\n' % (indent, t))
        return
    groups = [('Full page build — day is still a 🔒 placeholder',
               [x for x in todo if locked(page(wk, x[0]))]),
              ('Append to an existing page (tab · section · SUBJECTS · switchTab · quiz())',
               [x for x in todo if not locked(page(wk, x[0]))])]
    for title, rows in groups:
        if not rows:
            continue
        print('%s%s  (%d)' % (indent, title, len(rows)))
        for day, s in rows:
            print('%s   %s%s%s%s' % (indent, pad(day.title(), 11), pad(s['id'], 5),
                                     pad('%s %s' % (s['icon'], s['name']), 30), s['time']))
        print('')

def today_week():
    today = datetime.date.today()
    for num, w in WEEKS.items():
        if (datetime.date.fromisoformat(w['mon']) <= today
                <= datetime.date.fromisoformat(w['sun'])):
            return num, today
    return None, today

# ---------------------------------------------------------------- integrity
def check():
    print('\nTimetable ↔ DAY_SUBJECTS_MAP')
    ok = True
    for day in ORDER:
        want, have = set(ids_of(day)), {s['id'] for s in DAYS[day]}
        if want == have:
            print('  %-10s OK  (%s)' % (day.title(), ' '.join(ids_of(day))))
        else:
            ok = False
            print('  %-10s MISMATCH  timetable-only: %s · map-only: %s'
                  % (day.title(), ' '.join(sorted(want - have)) or '-',
                     ' '.join(sorted(have - want)) or '-'))

    if os.path.exists('dashboard.html'):
        m = re.search(r'var DAY_SUBJECTS_MAP=(\{.*?\});', open('dashboard.html').read(), re.S)
        same = m and json.loads(m.group(1)) == DAYS
        print('\nindex.html ↔ dashboard.html maps: %s'
              % ('identical' if same else 'DRIFTED — the dashboard will disagree'))
        ok = ok and bool(same)

    orphans = []
    for d in sorted(glob.glob('weeks/week*')):
        wk = int(re.search(r'(\d+)', d).group(1))
        for day in ORDER:
            extra = built_ids(page(wk, day)) - set(ids_of(day))
            for e in sorted(extra):
                orphans.append('%s  %s' % (page(wk, day), e))
    print('\nQuiz ids on pages that no timetable slot claims:')
    if orphans:
        ok = False
        for o in orphans:
            print('  %s   ← never registers as Done' % o)
    else:
        print('  none')
    print('\n%s\n' % ('All checks passed.' if ok else 'Fix the mismatches above.'))

# ---------------------------------------------------------------- main
def all_weeks():
    return sorted(int(re.search(r'(\d+)', d).group(1))
                  for d in glob.glob('weeks/week*') if os.path.isdir(d))

def ranges(nums):
    """[9,10,11,13] -> '9–11, 13'"""
    out, start = [], None
    for i, n in enumerate(nums):
        if start is None:
            start = n
        if i + 1 == len(nums) or nums[i + 1] != n + 1:
            out.append(str(start) if start == n else '%d–%d' % (start, n))
            start = None
    return ', '.join(out)

if do_check:
    check()

elif do_pend and week:
    print('')
    print_pending(int(week))

elif do_pend:
    print('')
    started, empty, done = [], [], []
    for wk in all_weeks():
        b, t = week_totals(wk)
        (done if b == t else started if b else empty).append(wk)
    for wk in started:
        print_pending(wk)
    if done:
        print('  ✅ Complete: week %s\n' % ranges(done))
    if empty:
        print('  Not started: week %s  (%d slots each, every day a placeholder)\n'
              % (ranges(empty), len(ids_of('monday')) + len(ids_of('tuesday'))
                 + len(ids_of('wednesday')) + len(ids_of('thursday'))
                 + len(ids_of('friday')) + len(ids_of('saturday'))
                 + len(ids_of('sunday'))))

elif do_today:
    wk, today = today_week()
    print('')
    if wk is None:
        print('  %s is outside the 41-week year (%s – %s).\n'
              % (today, WEEKS[1]['mon'], WEEKS[41]['sun']))
    else:
        day = ORDER[today.weekday()]
        print('Today · %s · Week %d of 41\n' % (today.strftime('%a %d %b %Y'), wk))
        print_day(wk, day, today)
        b, t = week_totals(wk)
        print('\n  Week %d overall: %d/%d built · page: weeks/week%02d/%s.html\n'
              % (wk, b, t, wk, day))

elif week:
    wk = int(week)
    w  = WEEKS.get(wk)
    span = ' · %s – %s' % (
        datetime.date.fromisoformat(w['mon']).strftime('%d %b'),
        datetime.date.fromisoformat(w['sun']).strftime('%d %b %Y')) if w else ''
    b, t = week_totals(wk)
    print('\nWeek %d of 41%s · %d/%d slots built\n' % (wk, span, b, t))
    for i, day in enumerate(ORDER):
        date = datetime.date.fromisoformat(w['mon']) + datetime.timedelta(days=i) if w else None
        print_day(wk, day, date)
        print('')
    if not show_all:
        print('  Add --all to show each slot\'s focus.\n')

else:
    nums = sorted(int(re.search(r'(\d+)', d).group(1))
                  for d in glob.glob('weeks/week*') if os.path.isdir(d))
    print('\n%-6s %-9s %-9s  %s' % ('Week', 'Built', 'Pending', 'Placeholder days'))
    print('-' * 52)
    gb = gt = 0
    for wk in nums:
        b, t = week_totals(wk)
        lk = [day[:3] for day in ORDER if locked(page(wk, day))]
        gb += b; gt += t
        print('%-6d %-9s %-9d  %s' % (wk, '%d/%d' % (b, t), t - b, ' '.join(lk) or '-'))
    print('-' * 52)
    print('%-6s %-9s %-9d\n' % ('all', '%d/%d' % (gb, gt), gt - gb))

    done = sum(1 for k, v in scores.items()
               if isinstance(v, dict) and v.get('totalQ')
               and v['bestScore'] / v['totalQ'] >= 0.6)
    dates = [v.get('lastDate') for v in scores.values()
             if isinstance(v, dict) and v.get('lastDate')]
    print('Student: %d sessions passed of %d recorded · last activity %s'
          % (done, len(scores), max(dates) if dates else 'never'))

    wk, today = today_week()
    if wk:
        day  = ORDER[today.weekday()]
        have = built_ids(page(wk, day))
        want = ids_of(day)
        print('Today:   Week %d · %s — %d/%d slots built (%s)'
              % (wk, day.title(), sum(1 for i in want if i in have), len(want),
                 ', '.join('%s %s' % (LABEL.get(i, i), '✓' if i in have else '·')
                           for i in want)))
    print('Detail:  ./status.sh <week> | today | --check\n')
PY
