# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

A static HTML/JS study app for a Class 6 ICSE student (academic year 2026–27, 41 weeks, Jun 2026 – Mar 2027). No build step, no framework, no npm. Everything runs directly in the browser via GitHub Pages. Progress is stored in `localStorage` and optionally synced to `progress.json` in this repo via the GitHub Contents API using a personal access token.

## Weekly timetable

The student follows a fixed weekly timetable. When adding content to a placeholder day, build the quiz subjects to match that day's scheduled subjects below. Weekdays start 6:00 PM; weekends have morning + afternoon blocks.

| Day | Slots (subject — focus) |
|-----|-------------------------|
| **Monday** | ➗ Maths Quick Practice (Tables/Fractions/Mental) · 🗣️ Kannada Literature (Reading/Vocab/Oral) · *Break* · 📖 English Literature (Reading & Summary) |
| **Tuesday** | ➗ Maths Quick Practice (3–5 Problems) · ⚡ Physics (Concepts & Numericals) · *Break* · 💻 Computer Science / Python (Coding & Logic) |
| **Wednesday** | 🌍 Map Revision (Geography Recall) · 🌍 Geography (Maps/Climate/Landforms) · *Break* · ✍️ English Grammar & Writing (Composition & Grammar) |
| **Thursday** | ➗ Maths Formula Recall (Mental Practice) · ⚗️ Chemistry (Concepts & Definitions) · *Break* · 🇫🇷 French (Grammar & Vocabulary) |
| **Friday** | 🧬 Science Diagram Recall (Biology Keywords) · 🗣️ Kannada Grammar & Writing (Grammar & Composition) · *Break* · 🧬 Biology (Diagrams & Concepts) |
| **Saturday AM** | ➗ Maths Problem Solving (Weekly Practice) · *Break* · 🏛️ History & Civics (Timelines & Civics) |
| **Saturday PM** | ⚡ Physics Quiz (Recall & Numericals) · ⚗️ Chemistry Quiz (Definitions & Concepts) · 🛑 Brain Break · 🧬 Biology Quiz (Diagrams & Labelling) |
| **Sunday AM** | 🗣️ Kannada (Reading & Writing) · 🇫🇷 French (Vocabulary & Sentences) · 🌍 Geography + 🏛️ History & Civics (Maps/Timelines/Key Terms) |
| **Sunday PM** | 🧠 Mixed Quiz Day · then Sports, Reading, Family Time |

## How to run locally

Open any `.html` file directly in a browser, or use a local server to avoid cross-origin issues:

```bash
python3 -m http.server 8080
# then open http://localhost:8080
```

No build, install, lint, or test commands exist. Changes are deployed by pushing to `main` (GitHub Pages serves from root).

## File structure and page hierarchy

```
index.html          ← Home: week grid, "today's session" banner, year progress
timetable.html      ← Static weekly timetable (subject per day/slot), self-contained
dashboard.html      ← Analytics: year-at-a-glance dot grid, subject table, streak
settings.html       ← GitHub token entry, manual cloud sync trigger
progress.json       ← Cloud sync store (written by the GitHub API, not by hand)
weeks/
  weekNN/
    index.html      ← Week overview: 7-day grid with per-subject score pills
    monday.html     ← Day session page (same structure for all 7 days)
    tuesday.html
    ... (wednesday–sunday)
```

41 week folders exist (`week01`–`week41`). Most days are placeholder "locked" cards until content is added.

## localStorage key schema

All progress keys follow this pattern:

```
icse_w{WW}_{day}_{subjectId}
```

Examples: `icse_w01_mon_m` (Week 1 Monday Maths), `icse_w02_tue_phy` (Week 2 Tuesday Physics).

- `WW` = zero-padded week number (01–41)
- `day` = `mon|tue|wed|thu|fri|sat|sun`
- `subjectId` = short id defined per session (e.g. `m`, `k`, `geo`, `phy`, `gh`, `mx`)

Each key stores: `{ attempts, bestScore, totalQ, lastDate, label }`.

A session is considered **Done** when `bestScore / totalQ >= 0.6` (60% threshold, defined as `THRESHOLD = 0.6` in `index.html`).

The cloud sync token is stored as `icse_gh_token`.

## Day session page pattern

Every day page (`weeks/weekNN/dayname.html`) follows this structure:

1. **Header** — gradient, logo emoji, day/week title, date/time
2. **Sticky tab bar** — one tab per subject (e.g. `📖 Study`, `❓ Quiz`)
3. **Progress bar strip** — `status-badge` + per-subject score pills + `☁️ Save` / `⚙️` buttons
4. **Content sections** — one `<div id="sec-{id}">` per tab, only `.active` one is visible
5. **`<script>`** — inline JS only; includes quiz engine, cloud sync, init calls

Each session page is **self-contained** — all CSS and JS are inline. No external dependencies.

## Quiz engine

The `quiz(id, questions, label)` function is copy-pasted into every session page that has a quiz. It:
- Renders one question at a time with 4 options
- Marks correct/wrong on click, shows explanation feedback (`.fb`)
- On finish: calls `saveScore()`, calls `refreshProgress()`, shows the done card
- `saveScore` writes to `localStorage` using `LS_PFX + '_' + id` as the key
- `LS_PFX` is set per session (e.g. `'icse_w02_wed'`)
- `SUBJECTS` array declares which tab IDs count toward the progress bar

## Subject colour conventions

- Default (Geography, English, general): indigo/purple `#4F46E5` / `#7C3AED`
- Physics / Chemistry / Science: green `#059669` / `#0D9488`
- Placeholder locked pages: generic indigo header, no tabs

## Adding content to a placeholder day

1. Open the target `weeks/weekNN/dayname.html` (currently a single-card locked placeholder)
2. Replace the entire file with the session page pattern above
3. Set the correct `LS_PFX` (e.g. `icse_w02_wed`), `SUBJECTS` array, tab IDs, and quiz data
4. Use `quiz(id, [...], 'Label')` for each scored tab; non-scored tabs (study notes / writing practice) are not added to `SUBJECTS`
5. The "Done" threshold is 60% — a 10-question quiz needs 6 correct

### Multi-subject days

A day page hosts **all of that day's timetable subjects**, each as its own quiz tab (plus optional study/writing tabs). Add a subject by appending to four things: a `<button class="tab" id="tab-{id}">`, a `<div id="sec-{id}">` section, the `SUBJECTS` array, and the `all = [...]` list inside `switchTab`. Then add one `quiz('{id}', [...], 'Label')` call. The shared `quiz()`/sync engine is per-id, so multiple quizzes coexist on one page. Use a day-level header (`📚` logo, "Maths · Kannada · English" subtitle) once a page has more than one subject.

### Subject id must match `DAY_SUBJECTS_MAP` (critical)

The home page (`index.html`) and `dashboard.html` each carry an identical `DAY_SUBJECTS_MAP` that drives completion tracking. A day is "Done" only when **every** id listed there has a passing score in `localStorage`. The id you pass to `quiz(id, …)` on a day page **must exactly equal** the id in `DAY_SUBJECTS_MAP` for that day in **both** files — otherwise the dashboard never registers the subject. Keep both copies in sync. (Known ids in use: `m` Maths, `k` Kannada, `e` English, `phy` Physics, `geo` Geography, `c` CS/Python, `ch` Chemistry, `f` French, `s` Science Diagrams, `b` Biology, `h` History & Civics, `gh` Geo+History, `mx` Mixed Quiz.) `DAY_SUBJECTS_MAP` `total` values are cosmetic — the Done calc uses the stored `totalQ`, not the map total.

## Cloud sync (settings.html)

`settings.html` uses `lsSet/lsGet/lsRemove` wrappers around `localStorage` to handle iOS Safari failures (Private Browsing = `QuotaExceededError`; Block All Cookies = `SecurityError`). The wrappers return `null/false` on failure and the UI shows an actionable message. Day session pages use raw `localStorage` calls (the sync is optional/best-effort there).

The GitHub API endpoint is:
```
PUT https://api.github.com/repos/icse-study/class6-study-sessions/contents/progress.json
```
Token must have **Contents: Read & Write** on this repo only.

### Sync merge rule (important)

When merging local and remote scores (`mergeScores` / `applyRemoteToLocal` in every page, and the inline merge in `settings.html`), `attempts` must use **`Math.max`**, never a sum. Summing on every sync compounds exponentially (Fibonacci-like) and blew the counter up to billions. Each merge wraps values in `satt(n)` — a sanitizer that resets absurd values (`>1000` or negative) to `1` — so any residual corruption self-heals as data flows through. `bestScore` already uses `max`; `attempts` now matches. If you copy the engine into a new page, keep the `satt()` helper and the `Math.max(satt(...), satt(...))` form.
