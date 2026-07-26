# class6-study-sessions

Class 6 ICSE full-year daily study sessions — Maths, Physics, Chemistry, Biology, Geography, History & Civics, Kannada, French, English and Computer Science.

A static study app for the **2026–27 academic year**: 41 weeks, June 2026 → March 2027. No build step, no framework, no npm — everything runs directly in the browser via GitHub Pages.

## Using it

Open `index.html` for the week grid and today's session. Or run a local server to avoid cross-origin issues:

```bash
python3 -m http.server 8080
# then open http://localhost:8080
```

Changes go live by pushing to `main` (GitHub Pages serves from the repo root).

## Pages

| Page | What it does |
|---|---|
| `index.html` | Home — week grid, today's session banner, year progress |
| `timetable.html` | The fixed weekly timetable, subject per day and slot |
| `dashboard.html` | Analytics — year-at-a-glance tiles, subject table, streak |
| `settings.html` | GitHub token entry and manual cloud sync |
| `weeks/weekNN/` | One folder per week: an overview plus seven day pages |

## How a session works

Each day page is self-contained — all CSS and JS inline — and hosts every subject on that day's timetable as its own tab. A quiz shows one question at a time with four options, marks it on click, and explains the answer. Options are shuffled on load so the correct answer isn't always in the same position.

A subject counts as **Done** at **60%** (`bestScore / totalQ >= 0.6`), so a 15-question quiz needs 9 correct. A *day* is Done only when every subject scheduled for it passes.

## Weekly timetable

Weekdays start at 6:00 PM; weekends have morning and afternoon blocks.

| Day | Subjects |
|---|---|
| **Monday** | ➗ Maths · 🗣️ Kannada Literature · 📖 English Literature |
| **Tuesday** | ➗ Maths · ⚡ Physics · 💻 Computer Science / Python |
| **Wednesday** | 🌍 Map Revision · 🌍 Geography · ✍️ English Grammar & Writing |
| **Thursday** | ➗ Maths Formula Recall · ⚗️ Chemistry · 🇫🇷 French |
| **Friday** | 🧬 Science Diagram Recall · 🗣️ Kannada Grammar · 🧬 Biology |
| **Saturday AM** | ➗ Maths Problem Solving · 🏛️ History & Civics |
| **Saturday PM** | ⚡ Physics Quiz · ⚗️ Chemistry Quiz · 🧬 Biology Quiz |
| **Sunday AM** | 🗣️ Kannada · 🇫🇷 French · 🌍 Geography + 🏛️ History |
| **Sunday PM** | 🧠 Mixed Quiz, then sports, reading and family time |

## Progress and sync

Scores live in `localStorage` under `icse_w{WW}_{day}_{subjectId}` — for example `icse_w02_tue_p` is Week 2 Tuesday Physics. Each entry stores `attempts`, `bestScore`, `totalQ`, `lastDate` and `label`.

Progress optionally syncs to `progress.json` in this repo through the GitHub Contents API. Add a personal access token in `settings.html`; it needs **Contents: Read & Write** on this repo only and is stored locally as `icse_gh_token`.

When local and remote scores merge, `attempts` uses `Math.max` — never a sum — and every value passes through a `satt()` sanitizer. See the sync section of `CLAUDE.md` for the invariants before touching that code.

## Adding content

Content is added week by week. Undeveloped days show a locked placeholder card until their session is built. `CLAUDE.md` documents how to fill one in — including the rule that a subject's id must match `DAY_SUBJECTS_MAP` in both `index.html` and `dashboard.html`, and must stay the same across all 41 weeks.
