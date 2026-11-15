# Servicio responsable de traducir un valor clínico a un semáforo green/yellow/red.
#
# Los umbrales son orientativos para monitorización de astronautas y están basados en:
#   - NASA Human Research Program (HRP): riesgos cardiovasculares, exposición a microgravedad
#     y contramedidas durante vuelos de larga duración.
#   - NASA-STD-3001 (NASA Space Flight Human-System Standard), Vol. 2: límites de salud
#     (usado como fuente del objetivo de CO₂ del entorno cerrado).
#   - CSA (Canadian Space Agency): radiación de neutrones (CANS) y pérdida ósea acelerada.
#   - American Heart Association (AHA): clasificación de presión arterial.
#   - ESA Spaceflight Physiology / guías clínicas terrestres (ACC/AHA, OMS) cuando no existe
#     un estándar específico de vuelo espacial.
# En un contexto real, un Flight Surgeon debe validar y ajustar estos rangos por misión.
class HealthEvaluator
  # PRESIÓN ARTERIAL SISTÓLICA (mmHg)
  # Clasificación AHA 2017 (https://www.heart.org/en/health-topics/high-blood-pressure):
  #   Normal < 120 · Elevated 120-129 · Stage 1 130-139 · Stage 2 >= 140 · Crisis >= 180.
  # Traducido a un único semáforo: verde < 120, amarillo 120-139, rojo >= 140.
  # El umbral bajo (< 90 / < 85) para hipotensión/ortostatismo queda marcado como
  # "unverified": no existe una fuente NASA citable para este límite en microgravedad.
  SYSTOLIC = { red_low: 85, yellow_low: 90, yellow_high: 119, red_high: 140, crisis_high: 180 }.freeze

  # PRESIÓN ARTERIAL DIASTÓLICA (mmHg)
  # Clasificación AHA 2017: Normal < 80 · Stage 1 80-89 · Stage 2 >= 90 · Crisis >= 120.
  # Semáforo: verde < 80, amarillo 80-89, rojo >= 90. Umbral bajo (< 60 / < 50)
  # marcado como "unverified" (sin fuente NASA específica).
  DIASTOLIC = { red_low: 50, yellow_low: 60, yellow_high: 79, red_high: 90, crisis_high: 120 }.freeze

  # FRECUENCIA CARDÍACA EN REPOSO (bpm)
  # La microgravedad reduce la carga cardíaca; taquicardia persistente > 100 puede reflejar
  # estrés, fiebre, arritmia o hipovolemia. Bradicardia < 40 es potencialmente sintomática.
  HEART_RATE = { red_low: 40, yellow_low: 50, yellow_high: 100, red_high: 130 }.freeze

  # GLUCOSA (mg/dL)
  # < 70 = hipoglucemia (riesgo de deterioro cognitivo en operaciones críticas).
  # >= 250 = hiperglucemia marcada; en vuelo puede agravarse por estrés y dieta.
  GLUCOSE = { red_low: 54, yellow_low: 70, yellow_high: 180, red_high: 250 }.freeze

  # TEMPERATURA CORPORAL (°C)
  # < 35.0 = hipotermia; >= 39.0 = fiebre alta. En entorno cerrado puede indicar infección.
  TEMPERATURE = { red_low: 35.0, yellow_low: 36.0, yellow_high: 38.0, red_high: 39.0 }.freeze

  # SUEÑO (horas en las últimas 24 h)
  # La NASA documenta ~6 h promedio en órbita, con déficit crónico y riesgo de fatiga.
  # < 4 h se considera crítico para la seguridad operacional.
  SLEEP = { red_low: 4.0, yellow_low: 6.0, yellow_high: 10.0, red_high: 12.0 }.freeze

  # ESTADO DE ÁNIMO (escala 1-10)
  # Herramienta de tamizaje del riesgo psicosocial (aislamiento/confinamiento).
  # <= 3 requiere intervención; 4-5 vigilancia activa.
  MOOD = { red_low: 4.0, yellow_low: 6.0 }.freeze

  # TIEMPO DE REACCIÓN (ms)
  # > 500 ms se asocia a fatiga cognitiva en tareas de vigilancia (CIPHER).
  REACTION_TIME = { yellow_high: 500, red_high: 800 }.freeze

  # COMIDAS COMPLETADAS (%)
  # < 50 % del plan diario compromete la reposición energética en microgravedad.
  MEALS_COMPLETED = { red_low: 25, yellow_low: 50 }.freeze

  # CONTACTO SOCIAL (min)
  # Menos de 10 min/día eleva el riesgo psicosocial (ARCHeR).
  SOCIAL_CONTACT = { red_low: 1, yellow_low: 10 }.freeze

  THRESHOLDS = {
    "blood_pressure_systolic" => SYSTOLIC,
    "blood_pressure_diastolic" => DIASTOLIC,
    "heart_rate" => HEART_RATE,
    "blood_glucose" => GLUCOSE,
    "body_temperature" => TEMPERATURE,
    "sleep_hours" => SLEEP,
    "mood_score" => MOOD,
    "reaction_time" => REACTION_TIME,
    "meals_completed_percent" => MEALS_COMPLETED,
    "social_contact_minutes" => SOCIAL_CONTACT
  }.freeze

  BASELINE_DEVIATION_PERCENT = 20
  BASELINE_PROTOCOL = "Deviation from the pre-flight baseline; may reflect adaptation to microgravity."
  CONFIRMED_EXTREME_NOTE = "Confirmed extreme value. Critical alert activated."
  COGNITIVE_FATIGUE_PROTOCOL = "Cognitive fatigue detected. Rest recommended (CIPHER / Spatial Cognition)."
  NUTRITION_INADEQUATE_PROTOCOL = "Inadequate Nutrition risk. Review the meal plan and caloric intake."
  ISOLATION_PROTOCOL = "Isolation risk (ARCHeR). Schedule contact with the crew and with Earth."

  # ---------------------------------------------------------------------------
  # Daily check NASA HRP / CSA
  # ---------------------------------------------------------------------------
  SANS_PROTOCOL = "SANS symptoms detected. Perform an immediate visual acuity test. Contact the Flight Surgeon."
  SENSORIMOTOR_PROTOCOL = "Dizziness reported: possible sensorimotor mismatch. Stop activity, check orthostatism and contact the Flight Surgeon if it persists."
  PSYCH_PROTOCOL = "High stress from isolation/confinement. Activate the psychosocial protocol, schedule contact with Earth and log the trend."
  BONE_PROTOCOL = "Bone density loss due to microgravity. Reinforce resistance exercise. Accelerated osteoporosis risk. ISS data (CSA) help prevent this on Earth."
  SKIN_PROTOCOL = "Skin lesion reported: possible host-microorganism interaction. Hygiene, watch for signs of infection and consult the Flight Surgeon."
  NUTRITION_PROTOCOL = "Caloric intake outside target. Adjust the nutritional plan, review hydration and log the trend."
  CO2_PROTOCOL = "Elevated CO₂ in a closed environment: increase ventilation/filtration and move away from the source. Check module sensors."

  # ---------------------------------------------------------------------------
  # NASA research studies: Immune Biomarkers, CIPHER, SANS/B-Complex, ARCHeR
  # ---------------------------------------------------------------------------
  IMMUNE_PROTOCOL = "Isolate, collect a dry saliva sample, notify Houston."
  SALIVA_SAMPLE_PROTOCOL = "Dry saliva sample pending (Immune Biomarkers / Artemis). Collect and register."
  SANS_STUDY_PROTOCOL = "SANS study: perform OCT and visual exam. Take the daily B-Complex supplement (B-Complex study)."
  CIPHER_BONE_PROTOCOL = "CIPHER study: bone loss and fracture risk during capsule egress. Monitor calcium/telomeres and reinforce countermeasures."
  CIPHER_EGRESS_PROTOCOL = "CIPHER study: Egress test (capsule egress) pending. Complete Egress Fitness before authorizing the activity."
  ARCHER_FATIGUE_PROTOCOL = "ARCHeR study: fatigue and sleep disruption. Sync actigraphy and repeat the cognitive performance survey."

  # Daily check field presentation metadata.
  DAILY_FIELD_META = {
    "bone_density_loss_percent" => { label: "Bone density loss", unit: "%", zone: "limbs", protocol: BONE_PROTOCOL },
    "co2_level" => { label: "CO₂ in closed environment", unit: "ppm", zone: nil, protocol: CO2_PROTOCOL },
    "stress_level" => { label: "Stress level", unit: "/10", zone: "psychological", protocol: PSYCH_PROTOCOL },
    "calories_intake" => { label: "Caloric intake", unit: "kcal", zone: "abdomen", protocol: NUTRITION_PROTOCOL },
    "vision_blurred" => { label: "Blurred vision (SANS)", unit: "", zone: "head", protocol: SANS_PROTOCOL },
    "dizziness_reported" => { label: "Dizziness reported", unit: "", zone: "chest", protocol: SENSORIMOTOR_PROTOCOL },
    "skin_rash" => { label: "Skin lesion", unit: "", zone: "abdomen", protocol: SKIN_PROTOCOL }
  }.freeze

  STATUS_RANK = { "red" => 0, "yellow" => 1, "green" => 2, "unknown" => 3 }.freeze

  # Evaluación agregada del chequeo diario. Devuelve:
  #   field_statuses:  { campo => green/yellow/red }
  #   zone_statuses:   { "head" => "red", "psychological" => "red", ... }
  #   zone_indicators: { "head" => [indicador sintético], ... } solo no verdes
  #   protocols:       { campo => { text:, urgency:, escalate: } }
  def self.daily_check_summary(check)
    field_statuses = DailyCheck::FIELDS.index_with do |field|
      daily_field_status(field, check.public_send(field))
    end

    zone_statuses = check_zone_statuses(field_statuses)
    zone_indicators = check_zone_indicators(check, field_statuses)
    protocols = DailyCheck::FIELDS.index_with do |field|
      status = field_statuses.fetch(field)
      {
        text: DAILY_FIELD_META.dig(field, :protocol),
        urgency: { "green" => "routine", "yellow" => "watch", "red" => "urgent" }.fetch(status, "routine"),
        escalate: status == "red"
      }
    end

    {
      field_statuses: field_statuses,
      zone_statuses: zone_statuses,
      zone_indicators: zone_indicators,
      protocols: protocols
    }
  end

  # Semáforo de un campo concreto del chequeo diario.
  def self.daily_field_status(field, value)
    case field.to_s
    when "vision_blurred", "dizziness_reported", "skin_rash"
      value ? (field.to_s == "vision_blurred" ? "red" : "yellow") : "green"
    when "bone_density_loss_percent"
      numeric_status(value) { |v| v > 1.5 ? "red" : v > 1.0 ? "yellow" : "green" }
    when "stress_level"
      numeric_status(value) { |v| v > 7 ? "red" : v > 5 ? "yellow" : "green" }
    when "co2_level"
      # Source: NASA-STD-3001 Vol. 2 — target < 1,000 ppm; critical > 2,000 ppm.
      numeric_status(value) { |v| v > 2_000 ? "red" : v > 1_000 ? "yellow" : "green" }
    when "calories_intake"
      # Source: NASA HRP - Space Physiology — minimum daily intake ~2,000 kcal.
      # Upper bounds are "unverified" (mission-specific, no citable NASA threshold).
      numeric_status(value) do |v|
        if v < 1_200 || v > 4_500 then "red"
        elsif v < 1_800 || v > 3_500 then "yellow"
        else "green"
        end
      end
    else
      "unknown"
    end
  end

  # El peor estado entre varios semáforos (criterio conservador de vuelo).
  def self.worst_status(*statuses)
    statuses.compact.min_by { |status| STATUS_RANK.fetch(status.to_s, 9) } || "green"
  end

  # Categoría AHA combinada de presión arterial (usa la peor de sistólica/diastólica).
  # Sustituye al nombre genérico "Crítico" por el nivel clínico correcto.
  def self.blood_pressure_category(systolic, diastolic)
    sys = systolic.to_f
    dia = diastolic.to_f

    return "Hypertensive Crisis" if sys >= 180 || dia >= 120
    return "Stage 2 Hypertension" if sys >= 140 || dia >= 90
    return "Stage 1 Hypertension" if (130..139).cover?(sys) || (80..89).cover?(dia)
    return "Elevated" if (120..129).cover?(sys)

    "Normal"
  end

  # Chequeo rápido de síntomas (Immune / SANS / Standard Measures).
  # Devuelve la misma estructura que daily_check_summary.
  def self.symptom_check_summary(check)
    field_statuses = {
      "rash_or_hives" => check.rash_or_hives ? "red" : "green",
      "vision_changes" => check.vision_changes ? "red" : "green",
      "dizziness_nausea" => check.dizziness_nausea ? "yellow" : "green"
    }

    zone_statuses = {}
    zone_indicators = Hash.new { |hash, key| hash[key] = [] }

    if check.rash_or_hives
      zone_statuses["immune"] = "red"
      zone_indicators["immune"] << research_indicator(
        check, type: "rash_or_hives", label: "Rash / hives (Immune)",
        value: "Yes", unit: "", status: "red", protocol: IMMUNE_PROTOCOL
      )
    end

    if check.vision_changes
      zone_statuses["head"] = "red"
      zone_indicators["head"] << research_indicator(
        check, type: "vision_changes", label: "Visual changes (SANS)",
        value: "Yes", unit: "", status: "red", protocol: SANS_PROTOCOL
      )
    end

    if check.dizziness_nausea
      zone_statuses["chest"] = worst_status(zone_statuses["chest"], "yellow")
      zone_indicators["chest"] << research_indicator(
        check, type: "dizziness_nausea", label: "Dizziness / nausea (Standard Measures)",
        value: "Yes", unit: "", status: "yellow", protocol: SENSORIMOTOR_PROTOCOL
      )
    end

    {
      field_statuses: field_statuses,
      zone_statuses: zone_statuses,
      zone_indicators: zone_indicators
    }
  end

  # Evaluación de los estudios de investigación. Devuelve la misma estructura
  # que daily_check_summary más `systemic_alert` (virus latente -> todo el cuerpo rojo).
  def self.research_summary(assessment, pre_eva_check: nil)
    zone_indicators = Hash.new { |hash, key| hash[key] = [] }
    zone_statuses = {}
    field_statuses = {}
    notes = {}
    systemic_alert = false

    if assessment
      # Immune Biomarkers / Standard Measures
      field_statuses["saliva_sample_taken"] = assessment.saliva_sample_taken ? "green" : "yellow"
      field_statuses["virus_reactivation_suspected"] = assessment.virus_reactivation_suspected ? "red" : "green"

      if assessment.virus_reactivation_suspected
        systemic_alert = true
        zone_statuses["immune"] = "red"
        zone_indicators["immune"] << research_indicator(
          assessment, type: "virus_reactivation_suspected", label: "Suspected viral reactivation",
          value: "Yes", unit: "", status: "red", protocol: IMMUNE_PROTOCOL
        )
        notes[:all] = IMMUNE_PROTOCOL
      elsif !assessment.saliva_sample_taken
        zone_statuses["immune"] = worst_status(zone_statuses["immune"], "yellow")
        zone_indicators["immune"] << research_indicator(
          assessment, type: "saliva_sample_taken", label: "Dry saliva sample",
          value: "Pending", unit: "", status: "yellow", protocol: SALIVA_SAMPLE_PROTOCOL
        )
      end

      # SANS / B-Complex
      oct_status = %w[abnormal borderline].include?(assessment.oct_scan_result) ? "yellow" : "green"
      field_statuses["oct_scan_result"] = oct_status
      vision_overdue = !assessment.vision_test_performed &&
                       ResearchAssessment.vision_test_overdue?(assessment.astronaut, on: assessment.assessed_on)
      field_statuses["vision_test_performed"] = vision_overdue ? "yellow" : "green"

      if oct_status == "yellow" || vision_overdue
        zone_statuses["head"] = worst_status(zone_statuses["head"], "yellow")
        detail = []
        detail << "OCT result: #{assessment.oct_scan_result}" unless assessment.oct_scan_result == "normal"
        detail << "visual test overdue (> 7 days)" if vision_overdue
        zone_indicators["head"] << research_indicator(
          assessment, type: "sans_study", label: "SANS study (OCT / vision)",
          value: detail.join(" · "), unit: "", status: "yellow", protocol: SANS_STUDY_PROTOCOL
        )
      end

      unless assessment.b_complex_supplement_taken
        zone_indicators["head"] << research_indicator(
          assessment, type: "b_complex_supplement", label: "B-Complex supplement",
          value: "Pending", unit: "", status: "yellow", protocol: SANS_STUDY_PROTOCOL
        )
      end

      # CIPHER: Bone Health, Telomeres, Spatial Cognition, Vestibular Health
      calcium_status = calcium_status(assessment.calcium_isotopes_level)
      field_statuses["calcium_isotopes_level"] = calcium_status
      if %w[yellow red].include?(calcium_status)
        zone_statuses["limbs"] = worst_status(zone_statuses["limbs"], calcium_status)
        zone_indicators["limbs"] << research_indicator(
          assessment, type: "calcium_isotopes_level", label: "Calcium / Bone Health (CIPHER)",
          value: format_value(assessment.calcium_isotopes_level), unit: "mg/dL",
          status: calcium_status, protocol: CIPHER_BONE_PROTOCOL
        )
      end

      telomere_status = telomere_status(assessment.telomere_length)
      field_statuses["telomere_length"] = telomere_status
      if %w[yellow red].include?(telomere_status)
        zone_statuses["limbs"] = worst_status(zone_statuses["limbs"], telomere_status)
        zone_indicators["limbs"] << research_indicator(
          assessment, type: "telomere_length", label: "Telomeres / aging (CIPHER)",
          value: format_value(assessment.telomere_length), unit: "kb",
          status: telomere_status, protocol: CIPHER_BONE_PROTOCOL
        )
      end

      spatial_status = score_status(assessment.spatial_cognition_score)
      field_statuses["spatial_cognition_score"] = spatial_status
      if %w[yellow red].include?(spatial_status)
        zone_statuses["head"] = worst_status(zone_statuses["head"], spatial_status)
        zone_indicators["head"] << research_indicator(
          assessment, type: "spatial_cognition_score", label: "Spatial cognition (CIPHER)",
          value: assessment.spatial_cognition_score, unit: "/100",
          status: spatial_status, protocol: "CIPHER study: low spatial cognition performance. Repeat the test and watch for fatigue."
        )
      end

      vestibular_status = assessment.vestibular_test_passed ? "green" : "yellow"
      field_statuses["vestibular_test_passed"] = vestibular_status
      if vestibular_status == "yellow"
        zone_statuses["limbs"] = worst_status(zone_statuses["limbs"], "yellow")
        zone_indicators["limbs"] << research_indicator(
          assessment, type: "vestibular_test_passed", label: "Vestibular test (CIPHER)",
          value: "Pending", unit: "", status: "yellow",
          protocol: "CIPHER study: vestibular test pending. Assess balance before capsule egress."
        )
      end

      # ARCHeR: actigrafía y encuesta de rendimiento cognitivo
      cognitive_status = score_status(assessment.cognitive_performance_survey_score)
      actigraphy_status = assessment.actigraphy_device_synced ? "green" : "yellow"
      field_statuses["cognitive_performance_survey_score"] = cognitive_status
      field_statuses["actigraphy_device_synced"] = actigraphy_status

      if %w[yellow red].include?(cognitive_status) || actigraphy_status == "yellow"
        status = worst_status(cognitive_status, actigraphy_status)
        zone_statuses["psychological"] = worst_status(zone_statuses["psychological"], status)
        zone_indicators["psychological"] << research_indicator(
          assessment, type: "archer_study", label: "ARCHeR: fatigue and sleep",
          value: cognitive_status == "green" ? "Actigraphy not synced" : "Low cognitive performance",
          unit: "", status: status, protocol: ARCHER_FATIGUE_PROTOCOL
        )
      end
    end

    # Egress Fitness vive en el checklist pre-EVA (CIPHER).
    egress_status = if pre_eva_check.nil?
      "unknown"
    else
      pre_eva_check.egress_fitness_completed? ? "green" : "yellow"
    end
    field_statuses["egress_fitness_completed"] = egress_status

    if egress_status == "yellow"
      zone_statuses["limbs"] = worst_status(zone_statuses["limbs"], "yellow")
      zone_indicators["limbs"] << research_indicator(
        pre_eva_check, type: "egress_fitness_completed", label: "Egress Fitness (CIPHER)",
        value: "Pending", unit: "", status: "yellow", protocol: CIPHER_EGRESS_PROTOCOL
      )
    end

    {
      field_statuses: field_statuses,
      zone_statuses: zone_statuses,
      zone_indicators: zone_indicators,
      notes: notes,
      systemic_alert: systemic_alert
    }
  end

  class << self
    private

    def calcium_status(value)
      return "unknown" if value.nil?

      value.to_f < 8.0 ? "red" : value.to_f < 8.5 ? "yellow" : "green"
    end

    def telomere_status(value)
      return "unknown" if value.nil?

      value.to_f < 3.5 ? "red" : value.to_f < 4.5 ? "yellow" : "green"
    end

    def score_status(value, red_below: 30, yellow_below: 50)
      return "unknown" if value.nil?

      value.to_i < red_below ? "red" : value.to_i < yellow_below ? "yellow" : "green"
    end

    def research_indicator(record, type:, label:, value:, unit:, status:, protocol:)
      {
        type: type,
        label: label,
        value: value,
        unit: unit,
        status: status,
        measured_at: research_timestamp(record),
        recommendation: {
          text: protocol,
          urgency: status == "red" ? "urgent" : "watch",
          escalate: status == "red"
        }
      }
    end

    def research_timestamp(record)
      time = if record.respond_to?(:assessed_on) && record.assessed_on
        record.assessed_on.to_time
      elsif record.respond_to?(:checked_at) && record.checked_at
        record.checked_at
      else
        Time.current
      end

      time.iso8601
    end

    def format_value(value)
      value.nil? ? "—" : format("%.2f", value.to_f)
    end

    def numeric_status(value)
      return "unknown" if value.nil?

      yield(value.to_f)
    end

    def check_zone_statuses(field_statuses)
      DAILY_FIELD_META.each_with_object({}) do |(field, meta), memo|
        zone = meta[:zone]
        next unless zone

        memo[zone] = worst_status(memo[zone], field_statuses.fetch(field))
      end
    end

    def check_zone_indicators(check, field_statuses)
      DAILY_FIELD_META.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(field, meta), memo|
        status = field_statuses.fetch(field)
        next if status == "green" || meta[:zone].nil?

        memo[meta[:zone]] << {
          type: field,
          label: meta[:label],
          value: display_value(field, check.public_send(field)),
          unit: meta[:unit],
          status: status,
          measured_at: (check.checked_on&.to_time || Time.current).iso8601,
          recommendation: {
            text: meta[:protocol],
            urgency: status == "red" ? "urgent" : "watch",
            escalate: status == "red"
          }
        }
      end
    end

    def display_value(field, value)
      case field.to_s
      when "vision_blurred", "dizziness_reported", "skin_rash"
        value ? "Yes" : "No"
      when "stress_level", "co2_level", "calories_intake"
        value.to_i
      else
        format("%.2f", value.to_f)
      end
    end
  end

  attr_reader :reading, :value, :indicator_type

  def initialize(reading)
    @reading = reading
    @value = reading.value.to_f
    @indicator_type = reading.indicator_type
  end

  # Devuelve "green", "yellow" o "red". Si el indicador no tiene umbrales,
  # degrada a "green" para no bloquear la captura de datos. Una desviación
  # > 20 % respecto a la línea base pre-vuelo escala un verde a amarillo.
  # Un valor extremo confirmado por el usuario siempre activa alerta crítica.
  def status
    return "red" if confirmed_extreme?

    calculated = threshold_status
    return calculated unless calculated == "green"

    baseline_deviation? ? "yellow" : "green"
  end

  # El usuario confirmó un valor extremo pero posible: alerta crítica explícita.
  def confirmed_extreme?
    reading.respond_to?(:confirmed?) && reading.confirmed? && reading.extreme_value?
  end

  # Desviación porcentual (absoluta) respecto a la baseline del indicador.
  # Devuelve nil si no hay baseline o si su valor es cero.
  def baseline_deviation_percent
    baseline = reading.baseline_reference
    return nil unless baseline

    baseline_value = baseline.value.to_f
    return nil if baseline_value.zero?

    ((value - baseline_value).abs / baseline_value.abs) * 100
  end

  def baseline_deviation?
    percent = baseline_deviation_percent
    percent.present? && percent > BASELINE_DEVIATION_PERCENT
  end

  # Explicación corta del resultado, útil para el panel lateral.
  # Para presión arterial usa la categoría AHA (Stage 2 / Hypertensive Crisis).
  def explanation
    return CONFIRMED_EXTREME_NOTE if confirmed_extreme?

    case status
    when "red"
      return "#{blood_pressure_category} — value outside the operational safety range: requires attention." if blood_pressure?

      "Value outside the operational safety range: requires attention."
    when "yellow"
      return BASELINE_PROTOCOL if baseline_deviation?

      "Value in the watch zone: repeat the measurement and observe the trend."
    else "Value within the expected range for spaceflight."
    end
  end

  private

  def blood_pressure?
    %w[blood_pressure_systolic blood_pressure_diastolic].include?(indicator_type)
  end

  def blood_pressure_category
    if indicator_type == "blood_pressure_diastolic"
      self.class.blood_pressure_category(0, value)
    else
      self.class.blood_pressure_category(value, 0)
    end
  end

  def threshold_status
    return "green" unless THRESHOLDS.key?(indicator_type)

    t = THRESHOLDS.fetch(indicator_type)

    return "red" if below_red?(t) || above_red?(t)
    return "yellow" if below_yellow?(t) || above_yellow?(t)

    "green"
  end

  def below_red?(t) = t[:red_low] && value < t[:red_low]
  def above_red?(t) = t[:red_high] && value >= t[:red_high]
  def below_yellow?(t) = t[:yellow_low] && value < t[:yellow_low]
  def above_yellow?(t) = t[:yellow_high] && value > t[:yellow_high]
end
