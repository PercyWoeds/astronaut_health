# Quipu Health — Final Handover Report

**Team:** Quipu Space · **Challenge:** NASA Space Apps 2026 — Health Monitoring Software for Astronauts on Space Missions
**Demo:** https://astronaut-health.onrender.com · **Stack:** Rails 8.1, PostgreSQL, Stimulus, Turbo, Three.js, Chart.js, Tailwind

---

## 1. How to run

```bash
bundle install
bin/rails db:create db:migrate db:seed
bin/dev          # http://localhost:3000
bin/rails test   # 119 tests, 0 failures
```

Seeds create 2 missions, 4 astronauts and 185 readings with visible green/yellow/red cases
(Ana Ríos = critical profile, Yuki Tanaka = healthy, Léa Dubois = psychosocial risk).

## 2. What the app does

- 3D interactive body map (Three.js + Raycaster) with a keyboard-accessible 2D fallback;
  zones are colored by worst-indicator status and clicking a zone opens the side panel.
- Rule-Based Flight Surgeon: explicit rules over the last 7 days produce the recommendation,
  the escalation text and the flight surgeon report. Not an AI model.
- Crew Health Score (0–100) with a "Why?" disclosure showing every deduction; capped at 69
  while any zone requires medical evaluation.
- 13 indicators (9 core + 3 experimental HRP-inspired + reaction time), each with unit
  conversion, a measurement guide and citations where they exist.
- Personal pre-flight baseline: deviation flags, baseline notes and baseline chart lines.
- Live NASA DONKI space weather (SEP events) with UTC timestamp and honest error fallback.
- Communication delay simulation (ISS / Moon ~1.3 s / Mars minutes) that adapts escalation text.
- Gamification (points, achievements, streaks), measurement reminders, symptom checker,
  daily NASA HRP/CSA check, research studies (Immune Biomarkers, SANS/B-Complex, CIPHER, ARCHeR),
  journal, pre-EVA checklist, ground reports with simulated round-trip reply time.
- Offline mode: service worker caches the app shell; readings taken without a link are queued
  in localStorage and synced on reconnect (`offline_controller.js`).
- Security: per-IP Rack rate limiter (`RATE_LIMIT_GENERAL` / `RATE_LIMIT_WRITE`, off in test),
  strong params, text length limits, CSRF token on every fetch POST.

## 3. Data honesty

- **Live NASA data:** DONKI space-weather events only.
- **Simulated:** all physiological readings, missions, astronauts, points, achievements,
  cumulative radiation dose and communication delay.
- **Provenance tags:** every reading carries `manual`, `device-recorded`, `lab-result`,
  `simulated` or `calculated`; lab-only fields (calcium isotopes, telomeres, OCT, bone density)
  are labeled "Lab result" in the UI.
- **Thresholds** are general adult references (AHA/ADA/WHO) or team-defined; NASA HRP informs
  hazard mapping, not numeric limits. CO₂ uses ISS reference points (not terrestrial).
- **Not a medical device.** Educational prototype; thresholds not validated by a clinician.

## 4. Validation performed

- `bin/rails test`: **119 runs, 527 assertions, 0 failures** (models, services, middleware,
  integration/API flows; parallelized).
- RuboCop: no offenses in files touched by this phase.
- HTTP smoke against the dev server (no browser available in this environment):
  - `GET /`, `/health_readings/new`, `/health_readings` → 200
  - `POST /health_readings` (JSON + CSRF) → 201 with evaluated status and recommendation
  - `GET /api/health_status`, `/api/health_readings/chart_data` (13 datasets), `/api/hrp_risks` (5 risks) → 200
  - `POST /demo/reset` (dev, no token) → 302 and re-seed
  - Rate limiter: request 301+ GETs/min → HTTP 429 with `Retry-After`
- Interactive WebGL click/drag behavior could not be exercised here; a manual pass on a
  machine with a browser is recommended before the final demo.

## 5. Known limitations (not included)

- No real authentication by role; no real device/wearables integration.
- No push notifications/email; no PDF/CSV export or clinical audit trail.
- No Capybara system tests (browser unavailable in this environment); service and model
  coverage is included instead.
- Basic gamification only (no weekly missions/ranking).

## 6. Deploy notes

- Render app; `DEPLOYED_AT` / `REVISION` env vars override the footer timestamp/revision
  (git fallback in local builds).
- `POST /demo/reset` is protected by `DEMO_RESET_TOKEN` outside development/test.
- Rate limits via `RATE_LIMIT_ENABLED`, `RATE_LIMIT_GENERAL`, `RATE_LIMIT_WRITE`
  (defaults 300/60 per minute; recommend an additional proxy limit in production).
