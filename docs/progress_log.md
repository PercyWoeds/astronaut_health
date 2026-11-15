# Quipu Space - Implementation Progress Log

## Project Overview
Quipu Space: Autonomous health monitoring software for astronauts on space missions (NASA Space Apps 2026).
Stack: Rails 8.1, PostgreSQL, Stimulus, Turbo, Three.js, Chart.js, Tailwind.

## Phase 0: Diagnosis & Plan
- [x] Initial test suite verification (99/99 passing).
- [x] Compare deployed vs local & inventory indicators/zones.

## Phase 1: Critical Fixes (P0)
- [x] Deployment parity, last deploy timestamp in footer, relative seed dates, protected demo reset action. Footer shows deploy timestamp + revision (DEPLOYED_AT/REVISION env, git fallback); seeds already use relative dates; POST /demo/reset re-runs seeds (footer button in dev/test; DEMO_RESET_TOKEN required elsewhere). Actual push/deploy of the Render app is manual.
- [x] CO₂: limits based on NASA SMAC 180-day (5.3 mmHg / 0.7%) and ISS operational limit (3.0 mmHg, symptoms @ 2.3 mmHg). Both units supported (ppm & mmHg), labeled "ISS reference points; not for terrestrial use". (HealthEvaluator + daily check modal + HRP panel.)
- [x] Radiation: 600 mSv career limit (NASA-STD-3001) instead of 150 mSv. Update neutron text to "Estimation: ~30% of ISS radiation is neutrons (CSA)". (hrp_risk_panel.rb.)
- [x] Comm Latency: ISS low latency, Moon ~1.3s, Mars orbital range (min to 20+ min, default demo configurable). Informational badge only (does not set zone to Watch). Updates escalation text and flight surgeon report. Artemis Gateway defaults to Moon. (comm_delay.rb; ARTEMIS-GW seeds destination moon.)
- [x] Analyst naming: Rename to "Rule-Based Flight Surgeon" everywhere (code, views, README, modals). No "AI".
- [x] Honest alert levels: Normal, Follow-up (yellow), Medical evaluation (red), "Possible emergency: follow mission medical protocols" (extreme values). Explicitly tag terrestrial vs spaceflight origin. (ALERT_LEVELS + EMERGENCY_LABEL + REFERENCE_SCOPES.)
- [x] Safety texts: Pre-EVA (4 checks, labeled "Simulation: operational checks, not a health assessment"), Telemedicine (labeled "Simulated link", no Tempus Pro naming), B-Complex study text ("If enrolled in the B-Complex study: ...").
- [x] Zone mapping: Sleep is not gravity-dependent hazard. Model hazards per indicator as list and state reason. (HAZARD_LISTS / DAILY_FIELD_HAZARDS; sleep_hours → isolation_confinement.)

## Phase 2: Experimental New Indicators
- [x] Hydration: fluid intake (mL/day), thirst/dry-mouth (0-10). Abdomen/Full body zone. Citation to Brain Fluid Pressure fluid shifts. (GUIDES/CITATIONS in health_reading.rb.)
- [x] Exercise & Muscle Performance: aerobic/resistance mins, RPE (1-10), soreness/weakness (0-10), optional device load/reps (documented as optional; no field). Limbs/Bones zone. HRP risk Reduced Cardiorespiratory and Musculoskeletal Fitness.
- [x] Balance & Vestibular: dizziness/motion sickness (0-10), disorientation episodes count. Stance test (sec, eyes open/closed) intentionally dropped together with the vestibular checkbox (commit 0ea47aa). "Not applicable in microgravity" tag. Limbs zone (performance metric) instead of Head subelement. HRP Altered Sensorimotor and Vestibular Function.

## Phase 3: Self-Evaluation, Validation & UX (P1)
- [x] Provenance tags: manual, simulated, device-recorded, lab-result, calculated. Calcium, telomeres, OCT and bone loss labeled "Lab result" in the form. (HealthReading DATA_ORIGINS; lab badges in daily check / research / biomarker modals; origin select in the form.)
- [x] Measurement guides: per-indicator guide text and citation, shown in the form from GUIDES/CITATIONS (health_reading.rb).
- [x] 3-layer validation & bounds: PLAUSIBILITY_RANGES reject impossible values, CONFIRMATION_RANGES require explicit confirmation for extreme-but-possible (flagged "confirmed"), and clinically abnormal readings raise watch/action alerts. (HealthReading validations; AnomalyDetector wired via after_create; team-defined limits.)
- [x] Summary & status logic: primary action card, score capped at 69 while a zone is red, deductions breakdown, latest alerts sorted by severity, baseline deviation notes, symptoms "Nothing to report" + timestamp, DONKI UTC timestamp with error fallback, dashed threshold/baseline chart lines.
- [x] Accessibility & fallbacks: icons+text, keyboard nav, aria labels, high-contrast pills, 2D body map fallback toggle. (Commits c339c38, 21d1cf7.)
- [x] Offline mode: ServiceWorker caches the app shell (public/service-worker.js); offline_controller.js queues readings in localStorage and syncs on reconnect; badge + toast UI.
- [x] Security & robustness: per-IP Rack rate limiter (app/middleware/rate_limiter.rb, env-tunable, off in test), strong params, text length limits (notes 1_000), CSRF token on every fetch.

## Phase 4: Tests, README & Handover
- [x] Comprehensive Minitest suite. 119 runs / 527 assertions, 0 failures (models, services, middleware, integration incl. API + all form flows). No Capybara system tests: no browser available in this environment.
- [x] Manual validation. HTTP smoke against the dev server: pages 200, CSRF POST 201, APIs 200 (chart_data 13 datasets, hrp_risks 5), demo reset 302 + re-seed, rate limiter 429 after 300 req/min. Interactive WebGL pass still recommended on a machine with a browser.
- [x] README update. Architecture tree refreshed, 13 indicators, plausibility/offline/rate-limiting moved to Covered, seeds count corrected (185 readings).
- [x] Final handover report. docs/handover_report.md (run steps, honesty about real vs simulated data, validation log, limitations, deploy notes).
