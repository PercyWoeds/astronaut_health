# 🚀 Quipu Health— Health Monitoring for Space Missions

**NASA Space Apps Challenge 2026 — Challenge: Create Health Monitoring Software for Astronauts on Space Missions**

[![Rails](https://img.shields.io/badge/Rails-8.1-red)](https://rubyonrails.org)
[![Three.js](https://img.shields.io/badge/Three.js-0.160-black)](https://threejs.org)
[![Tailwind](https://img.shields.io/badge/Tailwind-4.0-blue)](https://tailwindcss.com)
[![NASA HRP](https://img.shields.io/badge/NASA-Human%20Research%20Program-blue)](https://www.nasa.gov/hrp/)

**Team:** Quipu Space · **Demo:** [astronaut-health.onrender.com](https://astronaut-health.onrender.com)

---

## 📖 Executive Summary (For NASA Judges)

**The Problem:** Astronauts on deep space missions (Artemis, Mars) face the five hazards of human spaceflight identified by NASA's Human Research Program (HRP): space radiation, isolation and confinement, distance from Earth, altered gravity, and hostile/closed environments. With communication delays of many minutes each way on missions to Mars, crews cannot count on real-time medical guidance from Earth, and much of the responsibility for noticing health changes falls on the astronauts themselves.

**Our Solution:** Quipu Health is an autonomous health monitoring tool. It uses a **3D interactive body map** to show health status by anatomical zone, compares each reading with reference thresholds and with the astronaut's optional **pre-flight baseline**, and includes a **rule-based flight surgeon** that explains what is wrong, suggests an immediate action (for example, "Rest 5 minutes, re-measure") and tells the crew when to escalate. It also uses **NASA's DONKI API** for live space-weather alerts and shows a simulated radiation dose.

**Why It Matters:** Longer missions mean longer communication delays and less support from Earth. A tool that helps crews interpret their own data, decide when to escalate and keep a monitoring routine supports the autonomy those missions need. The Canadian Space Agency notes that research on how spaceflight affects the body has informed work on conditions such as osteoporosis, cardiovascular disorders and type 2 diabetes; self-monitoring tools may also be relevant on Earth where access to specialists is limited.

---

## ✨ Key Features

- **3D Interactive Body Map (Three.js):** Click a zone (for example Head, Chest, Abdomen, Limbs/Bones) to see its current status, the indicators behind it, the reason it is flagged and a recommended action. The overall status follows the worst indicator.
- **Rule-Based Flight Surgeon:** Explicit rules analyze the last 7 days of readings and generate recommendations. Thresholds are general adult references, not NASA values. This is **not** an AI model.
- **Crew Health Score (0–100):** A transparent rule-based score from sleep, mood, systolic and diastolic blood pressure, glucose and active DONKI alerts; every deduction is shown. While any zone is critical, the score is capped at 69.
- **Personal Pre-Flight Baseline:** Flags deviations from each astronaut's own reference, in addition to the reference thresholds.
- **Live Space Weather (DONKI API):** Uses NASA's DONKI API to alert the crew of Solar Energetic Particle (SEP) events.
- **Communication Delay Simulation:** Select ISS, Moon or Mars to simulate the one-way delay (near real-time for the ISS, about 1.3 s for the Moon, minutes for Mars) and adapt the escalation protocol.
- **Escalation:** In a critical state, the tool prepares a report for the flight surgeon.
- **Measurement Reminders:** Lists the measurements still pending today and opens the form with that indicator preselected.
- **Symptom Checker & Quick Reaction Test:** Tracks vision changes (SANS), immune reactivation (rash), dizziness and a simple reaction-time test as a fatigue signal.
- **Mission Risks & Studies:** Shows the five HRP hazards and tracks items inspired by HRP studies (Immune Biomarkers, SANS/B-Complex, CIPHER, ARCHeR).
- **Gamification:** Points, achievements and streaks to encourage consistent self-monitoring.

---

## 🔬 NASA Data & Scientific Sources

| Feature | NASA / CSA source |
| :--- | :--- |
| 5 Hazards of Spaceflight | [NASA HRP — Hazards](https://www.nasa.gov/hrp/hazards/) |
| Cardiovascular risk | [NASA HRP — Risk i=179](https://humanresearchroadmap.nasa.gov/Risks/risk.aspx?i=179) |
| SANS (vision) risk | [NASA HRP — Risk i=105](https://humanresearchroadmap.nasa.gov/Risks/risk.aspx?i=105) |
| Bone loss risk | [NASA HRP — Risk i=77](https://humanresearchroadmap.nasa.gov/Risks/risk.aspx?i=77) |
| Immune reactivation | [NASA HRP — Risk i=85](https://humanresearchroadmap.nasa.gov/Risks/risk.aspx?i=85) |
| HRP studies tracked | [NASA HRP — Ongoing HRP Research](https://www.nasa.gov/hrp/ongoing-hrp-research/) |
| Space weather (**live data**) | [NASA CCMC DONKI API — SEP](https://ccmc.gsfc.nasa.gov/DONKI-API/get/SEP) |
| Radiation context | [Canadian Space Agency — Monitoring radiation for astronaut health](https://www.asc-csa.gc.ca/eng/news/articles/2026/2026-02-26-monitoring-radiation-astronaut-health.asp) |
| Effects of spaceflight on the body | [Canadian Space Agency — Why do we conduct science experiments in space?](https://www.asc-csa.gc.ca/eng/iss/science/why-do-we-conduct-science-experiments-in-space.asp) |
| Reviewed, not used as data | [NASA OSDR — Inspiration4 datasets](https://www.nasa.gov/osdr-latest-news-i4-mission-datasets/) |

### What is real and what is simulated

- **Live NASA data:** space-weather events from the DONKI API.
- **Simulated:** all physiological readings, missions, astronauts, points and achievements (generated by `db/seeds.rb`), the cumulative radiation dose (the neutron share shown is an estimate based on Canadian Space Agency information) and the communication delay.
- **Reviewed but not used:** we reviewed NASA's Open Science Data Repository (Inspiration4 'omics datasets) and the description of Spaceflight Standard Measures. They do not contain the daily vitals this tool tracks, and Standard Measures data is access-controlled, so they were not used as data or as a source of thresholds.

### Data provenance, validation & offline

- **Provenance tags:** every reading carries a data origin — `manual`, `device-recorded`, `lab-result`, `simulated` or `calculated`. Lab-only fields (calcium isotopes, telomeres, OCT, bone density) are labeled "Lab result" in the UI.
- **Three-layer validation:** impossible values are rejected, extreme-but-possible values require explicit confirmation (flagged "confirmed"), and clinical anomalies raise the normal alert level.
- **Offline mode:** readings taken without a link are queued locally and synced on reconnect; a service worker (`public/service-worker.js`) keeps the app shell cached.
- **Rate limiting:** a per-IP Rack middleware (`app/middleware/rate_limiter.rb`) caps requests per minute; tune it with `RATE_LIMIT_GENERAL` / `RATE_LIMIT_WRITE` (disabled in the test environment).

---

## ⚠️ Scope and Limitations

- **Not a medical device.** It records, suggests and escalates; it does not diagnose.
- **Thresholds are indicative** and have not been validated by a clinician or a flight surgeon.
- **Only what a crew member can measure alone.** Blood counts, bone density, imaging, intracranial pressure and personal radiation dosimetry need laboratory or dedicated equipment and are out of scope. The bone-loss value in the daily check is entered from a medical exam (e.g., DEXA); the app does not measure it.
- **Simulated physiological data**, radiation dose and communication delay (see above).

---

## 🛠️ Technology Stack

- **Backend:** Ruby on Rails 8.1, PostgreSQL
- **Frontend:** Tailwind CSS 4, Stimulus.js, Three.js 0.160 (CDN), Chart.js 4 (CDN)
- **API:** NASA DONKI (space weather)
- **Decision logic:** rule-based engine (Ruby services)

---

## 🚀 Installation & Setup

```bash
cd astronaut_health
bundle install
bin/rails db:create db:migrate db:seed
bin/dev
```

Open http://localhost:3000.

---

## 📁 Architecture

```text
app/
├── controllers/
│   ├── dashboard_controller.rb          # main view
│   ├── health_readings_controller.rb    # new / create / index
│   └── api/
│       ├── health_status_controller.rb  # GET /api/health_status
│       └── health_readings_controller.rb# GET /api/health_readings/chart_data
├── javascript/controllers/
│   ├── body_3d_controller.js            # Three.js + Raycaster
│   ├── health_form_controller.js        # modal + fetch POST
│   ├── health_charts_controller.js      # Chart.js
│   └── mission_selector_controller.js   # mission/astronaut selector
├── models/
│   ├── mission.rb
│   ├── astronaut.rb
│   ├── health_reading.rb
│   ├── body_zone.rb
│   ├── achievement.rb
│   └── astronaut_achievement.rb
├── services/
│   ├── health_evaluator.rb              # value -> green/yellow/red
│   ├── recommendation_engine.rb         # action per indicator/status
│   ├── gamification_service.rb          # achievements
│   └── health_snapshot.rb               # aggregated zone status
└── views/
    ├── dashboard/index.html.erb         # 3D scene, panel, charts, modal
    └── health_readings/{new,index}.html.erb
```

### Data Flow

1. The selector sends `GET /?mission_id=...&astronaut_id=...`.
2. The form sends `POST /health_readings` with fetch (JSON).
3. `HealthReading` calls `HealthEvaluator`, which sets the status.
4. `GamificationService` awards achievements.
5. The controller returns JSON with the reading, the recommendation and achievements.
6. The frontend emits `health:reading-created`; `body_3d_controller` repaints the zone and `health_charts_controller` reloads the charts.
7. Clicking a zone makes `body_3d_controller` query `/api/health_status` and render the side panel.

---

## 🔬 Reference Thresholds (HealthEvaluator)

Indicative operating ranges, **not NASA values**. Blood pressure upper cut-offs follow the AHA stages (130/80 and 140/90) and the glucose ranges are informed by ADA guidance; heart rate, temperature, sleep and mood ranges, and all lower cut-offs, are team-defined.

| Indicator | Green | Yellow | Red | Rationale |
| :--- | :--- | :--- | :--- | :--- |
| Systolic BP (mmHg) | 90–129 | 85–89 / 130–139 | < 85 / ≥ 140 | ≥ 140 = stage 2 hypertension (AHA); < 85 = hypotension (team-defined) |
| Diastolic BP (mmHg) | 60–79 | 50–59 / 80–89 | < 50 / ≥ 90 | ≥ 90 = stage 2 hypertension (AHA); < 50 = hypotension (team-defined) |
| Heart rate (bpm) | 50–99 | 40–49 / 100–129 | < 40 / ≥ 130 | Team-defined |
| Glucose (mg/dL) | 70–179 | 54–69 / 180–249 | < 54 / ≥ 250 | Informed by ADA guidance |
| Temperature (°C) | 36.0–37.9 | 35.0–35.9 / 38.0–38.9 | < 35.0 / ≥ 39.0 | Team-defined; fever may signal infection in a closed environment |
| Sleep (h/24h) | 6–10 | 4–5.9 / 10.1–11.9 | < 4 / ≥ 12 | Team-defined; HRP lists sleep loss as a spaceflight risk |
| Mood (1–10) | ≥ 6 | 4–5 | ≤ 3 | Team-defined self-report scale |

References: [AHA](https://www.heart.org/en/health-topics/high-blood-pressure) (blood pressure), [ADA](https://diabetes.org/about-diabetes/diagnosis) (glucose), [WHO](https://www.who.int/news-room/fact-sheets/detail/hypertension) (hypertension).

---

## 🎮 Gamification

| Achievement | Points | Condition |
| :--- | :--- | :--- |
| First Reading | 10 | First measurement saved |
| Daily Check Complete | 50 | All indicators logged the same day |
| 3-Day Streak | 100 | 3 consecutive days with a complete check |
| 7-Day Streak | 250 | 7 consecutive days |
| Green Day | 75 | All indicators green for the day |

---

## ✅ Verification (End-to-End)

1. `bin/rails db:create db:migrate db:seed` creates 2 missions, 4 astronauts and 160 readings.
2. Open `/`: 3D body, overall red, chest/abdomen red, head/limbs yellow (Ana Ríos, critical profile).
3. Switch to "Mars Transit Analog 2027" and "Yuki Tanaka": body, panel, points and charts update to a healthy state. Switch to "Léa Dubois" for the psychosocial risk case.
4. Drag to rotate, zoom, click a zone: the panel shows indicators, values, status and recommendation.
5. Click "Register new measurement", select heart rate, value 75, save. A toast confirms, the table updates and the chart reloads.
6. Complete all indicators for the day to unlock achievements.
7. Query the JSON APIs listed in the architecture section.

### Demo reset and deploy info

- The footer shows the last deploy timestamp and revision. Set `DEPLOYED_AT` and `REVISION` env vars in production (local builds fall back to `.git`).
- `POST /demo/reset` recreates demo data by re-running `db/seeds.rb`. The button appears in the footer in development/test; in other environments it requires the shared `DEMO_RESET_TOKEN` env var (never enable it without a token in production).

---

## 📋 Hackathon Checklist

**Covered**

- ☑ Registration of 10 indicator types (systolic/diastolic blood pressure, heart rate, glucose, temperature, sleep, mood, reaction time, meals completed, social contact).
- ☑ 3D interactive human body with Raycaster and clickable zones.
- ☑ Side panel with zone, indicators, values, status, reason and recommendation.
- ☑ Green/yellow/red color coding per zone and indicator.
- ☑ Treatment/improvement guidance via `RecommendationEngine`.
- ☑ Dynamic charts with Chart.js (last 7 records per indicator).
- ☑ Measurement reminders for pending indicators.
- ☑ Escalation to the flight surgeon with simulated communication delay.
- ☑ Live NASA DONKI space-weather data.
- ☑ Basic gamification with points, achievements and streaks.
- ☑ JSON API for zone status and chart data.
- ☑ Seeds with 7 days of data and visible red cases.
- ☑ Multiple missions and astronauts per mission with a selector.
- ☑ Data origin tags on every reading and "Lab result" labels on lab-only fields.
- ☑ Three-layer validation: impossible values rejected, extreme values need confirmation.
- ☑ Offline queue for readings plus a cached app shell (service worker).
- ☑ Per-IP rate limiting middleware.
- ☑ No exotic gems: Rails, pg, Tailwind, Import Maps and Stimulus.

**Not included**

- ☐ Real authentication by role (astronaut, flight surgeon, mission admin).
- ☐ Real integration with medical devices or wearables.
- ☐ Push notifications / email to the flight surgeon.
- ☐ Exportable history to PDF/CSV and clinical audit.
- ☐ Advanced gamification: weekly missions, ranking, badges.
- ☐ System tests with Capybara (service and model coverage included).

---

## 🧠 NASA HRP: Coverage of the 5 Hazards

- **Radiation:** simulated cumulative dose and live space weather (DONKI) as context; no personal dosimetry.
- **Isolation / Confinement:** mood, sleep, social contact and psychosocial recommendations (inspired by ARCHeR).
- **Distance from Earth:** autonomous recommendations, simulated communication delay and escalation to the flight surgeon.
- **Gravity Fields:** blood pressure and heart rate (cardiovascular adaptations) and the bone-loss entry in the daily check-in (a value entered from a medical exam, not measured by the app).
- **Hostile / Closed Environments:** temperature, glucose and sleep as early signals.

---

## 📜 Credits & Licenses

- **3D Model:** "Ecorche - Anatomy study" by Beatriz Gomez Santamaria. Source: [Sketchfab](https://sketchfab.com/3d-models/ecorche-anatomy-study-e402d3d541eb4b199c57d5410f5d3c57). License: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Modified: zones are color-coded by health status.
- **Libraries:** Three.js 0.160.0 (MIT), Chart.js 4.4.1 (MIT), Stimulus 3.2.2 (MIT), Turbo 8.0.23 (MIT), Tailwind CSS 4.3.4 (MIT), Ruby on Rails 8.1.4.1 (MIT), Propshaft 1.3.2 (MIT).
- **Reference thresholds:** AHA (blood pressure), ADA (glucose) and WHO (hypertension) as general references. Design informed by NASA HRP; the numeric thresholds and operating ranges are team-defined. All physiological data is simulated.
- **AI disclosure:** AI tools (DeepSeek, ChatGPT/Claude) were used to assist in code generation, README drafting and presentation preparation. Reviewed by the team; clinical thresholds have not been validated by a clinician.

---

## ⚠️ Disclaimer

Educational prototype, not a medical device. Physiological data is simulated for demonstration; space weather data is live from the NASA DONKI API.

This project is not affiliated with, endorsed by, or certified by NASA. It was created for the NASA Space Apps Challenge. Clinical thresholds are indicative and must be validated by a flight surgeon before any real use.

---

## 📊 Data

All missions, astronauts, readings, points and achievements are simulated data generated by `db/seeds.rb`. No real personal data is used, no images of people are stored, and no sensitive information is collected.