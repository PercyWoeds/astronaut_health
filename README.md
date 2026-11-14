# 🚀 Quipu Space — Health Monitoring for Space Missions

**NASA Space Apps Challenge 2026 - Challenge: Create Health Monitoring Software for Astronauts on Space Missions**

[![Rails](https://img.shields.io/badge/Rails-8.1-red)](https://rubyonrails.org)
[![Three.js](https://img.shields.io/badge/Three.js-0.160-black)](https://threejs.org)
[![Tailwind](https://img.shields.io/badge/Tailwind-4.0-blue)](https://tailwindcss.com)
[![NASA HRP](https://img.shields.io/badge/NASA-Human%20Research%20Program-blue)](https://www.nasa.gov/hrp/)

**Team:** Chasqui Health · **Demo:** [astronaut-health.onrender.com](https://astronaut-health.onrender.com)

---

## 📖 Executive Summary (For NASA Judges)

**The Problem:** Astronauts on deep space missions (Artemis, Mars) face the 5 Hazards of Human Spaceflight identified by NASA HRP: Space Radiation, Isolation, Distance from Earth, Altered Gravity, and Hostile Environments. With communication delays of up to 20 minutes to Mars, they cannot rely on Earth for emergency medical guidance. They must be autonomous.

**Our Solution:** Quipu Space is an autonomous health monitoring tool. It uses a **3D interactive body map** (Three.js) to visualize health status by anatomical zone, a **personal pre-flight baseline** to detect anomalies, and an **AI Flight Surgeon** (rule-based engine) that provides immediate NASA-aligned protocols (e.g., "Take B-Complex, rest 5 minutes, re-measure"). It also integrates **NASA's DONKI API** for real-time space weather alerts and **CSA neutron radiation data**.

**Why It Matters:** It enables medical autonomy on Mars, reduces health risks, and its insights on bone loss and cardiovascular health can also benefit patients on Earth.

---

## ✨ Key Features
- **3D Interactive Body Map (Three.js):** Click on zones (Head, Chest, Limbs) to view real-time health status and NASA-specific risks (e.g., SANS, Cardiovascular Adaptations).
- **AI Flight Surgeon:** A rule-based engine that analyzes the last 7 health readings and generates recommendations based on NASA HRP thresholds.
- **Crew Health Score (0-100):** A composite metric based on sleep, mood, blood pressure, and radiation exposure.
- **Personal Pre-Flight Baseline:** Replaces generic thresholds with the astronaut's own baseline, reducing false alarms.
- **Real-Time Space Weather (DONKI API):** Integrates NASA's DONKI API to alert the crew of Solar Particle Events (SEP).
- **Communication Delay Simulation:** Select ISS, Moon, or Mars to simulate communication delays (1.3s vs 20 min) and adapt protocols.
- **Symptom Checker & Journaling:** Tracks SANS symptoms (vision changes), immune reactivation (rash), and psychological well-being (ARCHeR study).

---

## 🔬 NASA Data & Scientific Sources
| Feature | NASA/CSA Source |
| :--- | :--- |
| 5 Hazards of Spaceflight | [NASA HRP - Hazards](https://www.nasa.gov/hrp/hazards/) |
| Cardiovascular Risk | [NASA HRP - Risk i=179](https://humanresearchroadmap.nasa.gov/Risks/risk.aspx?i=179) |
| SANS (Vision) Risk | [NASA HRP - Risk i=105](https://humanresearchroadmap.nasa.gov/Risks/risk.aspx?i=105) |
| Bone Loss Risk | [NASA HRP - Risk i=77](https://humanresearchroadmap.nasa.gov/Risks/risk.aspx?i=77) |
| Immune Reactivation | [NASA HRP - Risk i=85](https://humanresearchroadmap.nasa.gov/Risks/risk.aspx?i=85) |
| Space Weather Data | [NASA CCMC DONKI API](https://ccmc.gsfc.nasa.gov/DONKI-API/get/SEP) |
| Neutron Radiation | [Canadian Space Agency (CSA) - CANS](https://www.asc-csa.gc.ca/eng/news/articles/2026/2026-02-26-monitoring-radiation-astronaut-health.asp) |

**References to OSDR / LSDA:** The thresholds and risk models are informed by studies archived in NASA's Open Science Data Repository (OSDR) and Life Sciences Data Archive (LSDA). They serve as scientific validation for our indicators.

---

## 🛠️ Technology Stack
- **Backend:** Ruby on Rails 8.1, PostgreSQL
- **Frontend:** Tailwind CSS 4, Stimulus.js, Three.js 0.160 (CDN), Chart.js 4 (CDN)
- **API:** NASA DONKI (Space Weather)
- **AI Logic:** Rule-based engine (Ruby Service)

---

## 🚀 Installation & Setup
```bash
cd astronaut_health
bundle install
bin/rails db:create db:migrate db:seed
bin/dev

Open http://localhost:3000.
📁 Architecture
text

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

Data Flow

    Selector sends GET /?mission_id=...&astronaut_id=....

    Form sends POST /health_readings with fetch (JSON).

    HealthReading calls HealthEvaluator (sets status).

    GamificationService awards achievements.

    Controller returns JSON with reading, recommendation, achievements.

    Frontend emits health:reading-created; body_3d_controller repaints zone; health_charts_controller reloads charts.

    Click on zone: body_3d_controller queries /api/health_status and renders the side panel.

🔬 Clinical Thresholds (HealthEvaluator)
Indicator   Green Yellow   Red   Rationale
Systolic BP (mmHg)   90–129   85–89 / 130–139   < 85 / ≥ 140   >140 = cardiovascular risk in microgravity; <85 = hypotension
Diastolic BP (mmHg)  60–79 50–59 / 80–89  < 50 / ≥ 90 ≥90 = hypertension; <50 = low output
Heart Rate (bpm)  50–99 40–49 / 100–129   < 40 / ≥ 130   Persistent tachycardia = stress, fever, arrhythmia
Glucose (mg/dL)   70–179   54–69 / 180–249   < 54 / ≥ 250   <70 = cognitive risk; ≥250 = marked hyperglycemia
Temperature (°C)  36.0–37.9   35.0–35.9 / 38.0–38.9   < 35.0 / ≥ 39.0   Fever in closed environment = infection
Sleep (h/24h)  6–10  4–5.9 / 10.1–11.9 < 4 / ≥ 12  NASA documents chronic sleep deficit in orbit
Mood (1–10) ≥ 6   4–5   ≤ 3   Psychosocial screening for isolation

References: NASA HRP, NASA-STD-3001, ESA Spaceflight Physiology, ACC/AHA, WHO.
🎮 Gamification
Achievement Points   Condition
First Reading  10 First measurement saved
Daily Check Complete 50 All 7 indicators logged same day
3-Day Streak   100   3 consecutive days with complete check
7-Day Streak   250   7 consecutive days
Green Day   75 All indicators green for the day
✅ Verification (End-to-End)

    bin/rails db:create db:migrate db:seed creates 2 missions, 4 astronauts, 160 readings.

    Open /: 3D body, overall red, chest/abdomen red, head/limbs yellow (Ana Ríos, critical profile).

    Switch to "Mars Transit Analog 2027" and "Yuki Tanaka": body, panel, points, charts update to healthy state. Switch to "Léa Dubois" for psychosocial risk case.

    Drag to rotate, zoom, click zone: panel shows indicators, values, status, recommendation.

    Click "Register new measurement", select heart_rate, value 75, save. Toast confirms, table updates, chart reloads.

    Complete all 7 indicators for the day to unlock achievements.

    Consume JSON APIs listed above.

📋 Hackathon Checklist
Covered

    ☑

    Registration of 6 indicator groups (7 types, including systolic/diastolic BP).
    ☑

    3D interactive human body with Raycaster and clickable zones.
    ☑

    Side panel with zone, indicators, value, status, and recommendation.
    ☑

    Green/yellow/red color coding per zone and indicator.
    ☑

    Treatment/improvement guide via RecommendationEngine.
    ☑

    Dynamic charts with Chart.js (last 7 records per indicator).
    ☑

    Basic gamification with points, achievements, streaks.
    ☑

    JSON API for zone status and chart data.
    ☑

    Seeds with 7 days of data and visible red cases.
    ☑

    Multiple missions and astronauts per mission with selector.
    ☑

    APIs and form filtered by mission_id / astronaut_id.
    ☑

    No exotic gems; only Rails + pg + Tailwind + Import Maps + Stimulus.

Nice to have (not included)

    □

    Real authentication by role (Astronaut, Flight Surgeon, Mission Admin).
    □

    Real integration with medical devices or wearables.
    □

    Push notifications / email to Flight Surgeon.
    □

    Exportable history to PDF/CSV and clinical audit.
    □

    Advanced gamification: weekly missions, ranking, badges.
    □

    System tests with Capybara and service coverage.

🧠 NASA HRP: The 5 Hazards Coverage

    Radiation: Indirect tracking (temperature, mood, fatigue).

    Isolation/Confinement: mood_score, sleep, psychosocial recommendations.

    Distance from Earth: Autonomous recommendations and escalation to Flight Surgeon.

    Gravity Fields: BP, heart rate, sleep to detect deconditioning.

    Hostile/Closed Environments: Temperature, glucose, sleep as early signals.

📜 Credits & Licenses

    3D Model: "Ecorche - Anatomy study" by Beatriz Gomez Santamaria. Source: Sketchfab. License: CC BY 4.0. Modified: zones are color-coded by health status.

    Libraries: Three.js 0.160.0 (MIT), Chart.js 4.4.1 (MIT), Stimulus 3.2.2 (MIT), Turbo 8.0.23 (MIT), Tailwind CSS 4.3.4 (MIT), Ruby on Rails 8.1.4.1 (MIT), Propshaft 1.3.2 (MIT).

    Reference Thresholds: AHA (BP), ADA (glucose), WHO (hypertension), NASA HRP (spaceflight risks).

    AI Disclosure: AI tools (ChatGPT/Claude) were used to assist in code generation, README drafting, and presentation preparation. All medical logic and NASA data citations were manually verified.

⚠️ Disclaimer

Educational prototype, not a medical device. All data is simulated.
This project is not affiliated with, endorsed by, or certified by NASA. It was created for the NASA Space Apps Challenge. Clinical thresholds are indicative and must be validated by a Flight Surgeon before any real use.
📊 Data

All missions, astronauts, readings, points, and achievements are simulated data generated by db/seeds.rb. No real personal data is used, no images of people are stored, and no sensitive information is collected.