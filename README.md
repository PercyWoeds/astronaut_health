# Astronaut Health — Monitor de salud para misiones espaciales

MVP funcional para la hackathon de NASA. Permite a un astronauta registrar sus
indicadores de salud, visualizar un cuerpo humano 3D interactivo con semáforo
verde/amarillo/rojo, recibir recomendaciones operativas, consultar tendencias y
desbloquear logros de gamificación.

**Equipo:** Chasqui Health · **Reto:** [NOMBRE DEL RETO] · **Demo:** [SE COMPLETA TRAS DESPLEGAR]

Stack: **Ruby on Rails 8.1** (compatible con Rails 7+), **PostgreSQL**,
**Tailwind CSS 4**, **Stimulus + Import Maps**, **Three.js 0.160** y
**Chart.js 4** (ambos por CDN).

---

## 1. Requisitos

- Ruby 3.2+ (probado con 3.4.8)
- Rails 7.1+ (probado con 8.1.4.1)
- PostgreSQL 14+ en ejecución
- Conexión a internet para cargar Three.js y Chart.js desde CDN
- No requiere Node.js: el proyecto usa Import Maps

## 2. Puesta en marcha

```bash
cd astronaut_health
bundle install
bin/rails db:create db:migrate db:seed
bin/dev
```

Abrir <http://localhost:3000>.

`bin/dev` levanta Puma y el watcher de Tailwind. Si prefieres el servidor clásico:

```bash
bin/rails tailwindcss:build
bin/rails server
```

### Misiones y astronautas demo

No hay autenticación en este MVP. El dashboard incluye dos selectores:
**Misión** y **Astronauta**. La selección se propaga por query params
(`?mission_id=2&astronaut_id=2`) y todas las APIs quedan filtradas por ese astronauta.

| Misión | Código | Astronautas | Perfil |
| --- | --- | --- | --- |
| Artemis · Gateway Sim 2026 | `ARTEMIS-GW` | Ana Ríos, Carlos Méndez | crítico / vigilancia |
| Mars Transit Analog 2027 | `MARS-TRANSIT` | Yuki Tanaka, Léa Dubois | saludable / psicosocial |

Al abrir `/` se selecciona la primera misión y su primer astronauta (Ana Ríos).
Para multiusuario real, sustituir `current_mission` / `requested_astronaut` por
`current_user.mission` / `current_user.astronaut` y añadir Devise o `has_secure_password`.

## 3. Cómo se generó el proyecto

```bash
rails new astronaut_health --database=postgresql --css=tailwind

bin/rails generate model Mission name:string code:string description:text status:string
bin/rails generate model Astronaut name:string mission:references
bin/rails generate model HealthReading astronaut:references indicator_type:string value:float unit:string measured_at:datetime status:string
bin/rails generate model BodyZone name:string description:text related_indicators:jsonb
bin/rails generate model Achievement name:string description:text points:integer
bin/rails generate model AstronautAchievement astronaut:references achievement:references awarded_at:datetime
```

## 4. Arquitectura

```
app/
├── controllers/
│   ├── dashboard_controller.rb          # vista principal
│   ├── health_readings_controller.rb    # new / create / index (HTML + JSON)
│   └── api/
│       ├── health_status_controller.rb  # GET /api/health_status
│       └── health_readings_controller.rb# GET /api/health_readings/chart_data
├── javascript/controllers/
│   ├── body_3d_controller.js            # Three.js + Raycaster + panel
│   ├── health_form_controller.js        # modal + fetch POST
│   ├── health_charts_controller.js      # Chart.js + tabla dinámica
│   └── mission_selector_controller.js   # cambio de misión/astronauta
├── models/
│   ├── mission.rb                       # agrupa astronautas por misión
│   ├── astronaut.rb
│   ├── health_reading.rb                # catálogo de indicadores y scopes
│   ├── body_zone.rb                     # zona -> indicadores (jsonb)
│   ├── achievement.rb
│   └── astronaut_achievement.rb
├── services/
│   ├── health_evaluator.rb              # valor -> green/yellow/red
│   ├── recommendation_engine.rb         # acción concreta por indicador/status
│   ├── gamification_service.rb          # logros y rachas
│   └── health_snapshot.rb               # agregado por zona para la API
└── views/
    ├── dashboard/index.html.erb         # escena 3D, panel, gráficas, modal
    └── health_readings/{new,index}.html.erb
```

### Flujo de datos

0. El selector envía `GET /?mission_id=...&astronaut_id=...`; el dashboard
   reconstruye URLs y datos solo para ese astronauta.
1. El formulario envía `POST /health_readings?mission_id=...&astronaut_id=...` con `fetch` (JSON).
2. `HealthReading` ejecuta `before_validation` y llama a `HealthEvaluator`,
   que asigna el `status` antes de guardar.
3. `GamificationService` evalúa si el chequeo diario está completo y otorga logros.
4. El controlador responde JSON con la lectura, su recomendación y los logros nuevos.
5. El frontend emite `health:reading-created`; `body_3d_controller` repinta la zona
   y `health_charts_controller` recarga las gráficas y la tabla.
6. Al hacer click en una zona, `body_3d_controller` consulta `/api/health_status`
   (ya cargado) y pinta el panel lateral con indicadores y recomendaciones.

## 5. Rutas principales

| Método | Ruta | Uso |
| --- | --- | --- |
| GET | `/` | Dashboard; acepta `mission_id` y `astronaut_id` |
| GET | `/health_readings` | Historial HTML / JSON del astronauta seleccionado |
| GET | `/health_readings/new` | Formulario alternativo |
| POST | `/health_readings` | Crear medición (HTML o JSON) |
| GET | `/api/health_status?astronaut_id=2` | Estado por zona del astronauta |
| GET | `/api/health_readings/chart_data?astronaut_id=2` | Últimos 7 valores por indicador |
| GET | `/api/health_readings?astronaut_id=2` | Lecturas recientes en JSON |

Los endpoints aceptan también `mission_id`; el astronauta siempre se resuelve
dentro de esa misión para evitar mezclar datos entre tripulaciones.

Ejemplos:

```bash
curl "http://localhost:3000/api/health_status?mission_id=2&astronaut_id=2" | jq
curl "http://localhost:3000/api/health_readings/chart_data?astronaut_id=3" | jq
curl -X POST "http://localhost:3000/health_readings?astronaut_id=2" \
  -H "Content-Type: application/json" \
  -H "X-CSRF-Token: <token>" \
  -d '{"health_reading":{"indicator_type":"heart_rate","value":75,"unit":"bpm"}}'
```

> Para el POST por consola necesitas cookie de sesión y token CSRF, o usar el
> formulario del dashboard. La app no expone una API sin CSRF a propósito.

## 6. Umbrales clínicos (`HealthEvaluator`)

Los valores son orientativos para monitorización y deben ser validados por un
Flight Surgeon antes de un uso real.

| Indicador | Verde | Amarillo | Rojo | Justificación breve |
| --- | --- | --- | --- | --- |
| PA sistólica (mmHg) | 90–129 | 85–89 / 130–139 | < 85 / ≥ 140 | > 140 = riesgo cardiovascular en microgravedad; < 85 = hipotensión/ortostatismo |
| PA diastólica (mmHg) | 60–79 | 50–59 / 80–89 | < 50 / ≥ 90 | ≥ 90 = hipertensión; < 50 = bajo gasto/deshidratación |
| Frecuencia cardíaca (bpm) | 50–99 | 40–49 / 100–129 | < 40 / ≥ 130 | Taquicardia persistente = estrés, fiebre, hipovolemia o arritmia |
| Glucosa (mg/dL) | 70–179 | 54–69 / 180–249 | < 54 / ≥ 250 | < 70 = hipoglucemia con riesgo cognitivo; ≥ 250 = hiperglucemia marcada |
| Temperatura (°C) | 36.0–37.9 | 35.0–35.9 / 38.0–38.9 | < 35.0 / ≥ 39.0 | Fiebre en entorno cerrado = posible infección; < 35 = hipotermia |
| Sueño (h/24 h) | 6–10 | 4–5.9 / 10.1–11.9 | < 4 / ≥ 12 | La NASA documenta déficit crónico de sueño en órbita y riesgo de fatiga |
| Estado de ánimo (1–10) | ≥ 6 | 4–5 | ≤ 3 | Tamizaje de riesgo psicosocial por aislamiento/confinamiento |

Referencias generales: NASA Human Research Program (HRP), NASA-STD-3001 Vol. 1
(Space Flight Human-System Standard), ESA Spaceflight Physiology y guías
clínicas terrestres ACC/AHA y OMS.

## 7. Three.js: qué se hace en JavaScript y por qué

- La escena, cámara, luces, `OrbitControls`, el `Raycaster`, el pintado de meshes
  y el panel lateral viven en `body_3d_controller.js`. Rails no puede renderizar
  WebGL en el servidor; solo entrega el HTML y los datos JSON.
- El cuerpo es un **placeholder geométrico low-poly** construido con primitivas
  (`SphereGeometry`, `CapsuleGeometry`, etc.). No depende de un GLTF externo y
  funciona sin descargar modelos.
- Para usar un modelo GLTF real: cargar `GLTFLoader`, recorrer el modelo y asignar
  `mesh.userData.zone` con los nombres `head`, `chest`, `abdomen` o `limbs`.
  El resto de la lógica (Raycaster, colores, panel) se reutiliza sin cambios.
- El semáforo se aplica por zona usando el **peor** estado entre sus indicadores
  (criterio conservador para vuelo).

## 8. Gamificación incluida

| Logro | Puntos | Condición |
| --- | --- | --- |
| Primer registro | 10 | Primera medición guardada |
| Chequeo diario completo | 50 | Los 7 indicadores registrados el mismo día |
| Racha de 3 días | 100 | 3 días consecutivos con chequeo completo |
| Racha de 7 días | 250 | 7 días consecutivos |
| Día en verde | 75 | Todos los indicadores del día en verde |

## 9. Verificación end-to-end

1. `bin/rails db:create db:migrate db:seed` debe terminar con 2 misiones, 4 astronautas y 160 lecturas.
2. Abrir `/`: se ven cuerpo 3D, estado general rojo, zonas caja torácica/abdomen
   en rojo, cabeza/extremidades en amarillo (Ana Ríos, perfil crítico).
3. Cambiar a la misión “Mars Transit Analog 2027” y al astronauta “Yuki Tanaka”:
   el cuerpo, el panel, los puntos y las gráficas cambian a su estado saludable.
   Cambiar a “Léa Dubois” muestra el caso de riesgo psicosocial.
3. Arrastrar para rotar, hacer zoom y click en una zona: el panel lateral muestra
   indicadores, valores, estado y recomendación.
4. Pulsar “Registrar nueva medición”, elegir `heart_rate`, valor `75`, guardar.
   El toast confirma, la tabla se actualiza y la gráfica se recarga.
5. Cambiar el selector de la gráfica para ver la evolución de cada indicador.
6. Completar los 7 indicadores del día (si falta alguno) para desbloquear logros.
7. Consumir las APIs JSON listadas arriba.

Pruebas automatizadas de servicios (si se añaden): `bin/rails test`.

## 10. Checklist hackathon

### Cumple

- [x] Registro de los 6 grupos de indicadores (7 tipos, incluida PA sistólica/diastólica).
- [x] Cuerpo humano 3D interactivo con Raycaster y zonas clickeables.
- [x] Panel lateral con zona, indicadores, valor, estado y recomendación.
- [x] Código de colores verde/amarillo/rojo por zona e indicador.
- [x] Guía de tratamiento/mejora mediante `RecommendationEngine`.
- [x] Gráficas dinámicas con Chart.js (últimos 7 registros por indicador).
- [x] Gamificación básica con puntos, logros y rachas.
- [x] API JSON para estado por zona y datos de gráficas.
- [x] Seeds con 7 días de datos y casos rojos visibles.
- [x] Múltiples misiones y múltiples astronautas por misión con selector.
- [x] APIs y formulario filtrados por `mission_id` / `astronaut_id`.
- [x] Sin gemas exóticas; solo Rails + pg + Tailwind + Import Maps + Stimulus.

### Nice to have (no incluido)

- [ ] Autenticación real por rol (astronauta, Flight Surgeon, administrador de misión).
- [ ] Asignación temporal de astronautas a misiones y tripulaciones de relevo.
- [ ] Entornos adicionales (rover, base lunar, EVA) con riesgos específicos.
- [ ] Integración real con dispositivos médicos o wearables.
- [ ] Animaciones de modelos GLTF con partes anatómicas nombradas.
- [ ] Notificaciones push / correo al Flight Surgeon.
- [ ] Historial exportable a PDF/CSV y auditoría clínica.
- [ ] Gráficas con bandas de referencia y detección de tendencias.
- [ ] Gamificación avanzada: misiones semanales, ranking, insignias.
- [ ] Tests de sistema con Capybara y cobertura de servicios.

## 11. Nota sobre los 5 peligros de NASA HRP

La app cubre los indicadores fisiológicos y psicosociales asociados a:

1. **Radiación:** seguimiento indirecto (temperatura, ánimo, fatiga).
2. **Aislamiento/confinamiento:** `mood_score`, sueño y recomendaciones psicosociales.
3. **Distancia a la Tierra:** recomendaciones autónomas y escalado al Flight Surgeon.
4. **Campos gravitatorios:** PA, frecuencia cardíaca y sueño para detectar decondicionamiento.
5. **Entornos cerrados hostiles:** temperatura, glucosa y sueño como señales tempranas.

## 12. Credits & licenses

- **Modelo 3D:** “Ecorche - Anatomy study” by Beatriz Gomez Santamaria. Source: Sketchfab. License: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Link: <https://sketchfab.com/3d-models/ecorche-anatomy-study-e402d3d541eb4b199c57d5410f5d3c57>. Modified: zones are color-coded by health status.
- **Librerías:** Three.js 0.160.0 (MIT), Chart.js 4.4.1 (MIT), Stimulus 3.2.2 (MIT), Turbo 8.0.23 (MIT), Tailwind CSS 4.3.4 (MIT), Ruby on Rails 8.1.4.1 (MIT), Propshaft 1.3.2 (MIT).
- **Tipografía:** pila del sistema (`ui-sans-serif` / `system-ui`); no se distribuyen fuentes externas.
- **Umbrales de referencia:** AHA (presión arterial), ADA (glucosa), OMS (hipertensión) y NASA HRP (riesgos de vuelo espacial).

El detalle completo está en [CREDITS.md](CREDITS.md) y en el footer visible del dashboard.

## 13. Disclaimer

**Educational prototype, not a medical device. All data is simulated.**

Este proyecto no está afiliado, respaldado ni certificado por NASA. Fue creado
para el NASA Space Apps Challenge. Los umbrales clínicos son orientativos y
deben ser validados por un Flight Surgeon antes de cualquier uso real.

## 14. Data

Todas las misiones, astronautas, mediciones, puntos y logros son datos
simulados generados por `db/seeds.rb`. No se usan datos personales reales, no se
almacenan imágenes de personas y no se recopila información sensible.


