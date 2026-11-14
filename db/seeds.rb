# Datos de demostración para la hackathon.
# Ejecutar con: bin/rails db:seed
# El script es destructivo con los datos demo: limpia misiones, astronautas,
# lecturas y logros antes de recrearlos. No toca BodyZone (catálogo global).

puts "Limpiando datos demo…"
GroundReport.delete_all
Alert.delete_all
Baseline.delete_all
SymptomReport.delete_all
AstronautAchievement.delete_all
HealthReading.delete_all
DailyCheck.delete_all
ResearchAssessment.delete_all
BiomarkerSample.delete_all
JournalEntry.delete_all
PreEvaCheck.delete_all
SymptomCheck.delete_all
Astronaut.delete_all
Mission.delete_all
Achievement.delete_all

puts "Creando indicadores del catálogo…"
Indicator.seed_catalog!

puts "Creando zonas corporales…"
zones = [
  {
    name: "head",
    description: "Cabeza y estado neuropsicológico: termorregulación, estado de ánimo y fatiga cognitiva.",
    related_indicators: %w[body_temperature mood_score sleep_hours reaction_time]
  },
  {
    name: "chest",
    description: "Tórax: sistema cardiovascular. Presión arterial y frecuencia cardíaca en reposo.",
    related_indicators: %w[blood_pressure_systolic blood_pressure_diastolic heart_rate]
  },
  {
    name: "abdomen",
    description: "Abdomen: metabolismo y control glucémico durante la misión.",
    related_indicators: %w[blood_glucose meals_completed_percent]
  },
  {
    name: "limbs",
    description: "Extremidades: rendimiento físico, recuperación muscular y horas de sueño.",
    related_indicators: %w[sleep_hours]
  }
]

zones.each do |attrs|
  BodyZone.find_or_initialize_by(name: attrs[:name]).update!(attrs)
end

puts "Creando misiones…"
missions = {}
[
  {
    name: "Artemis · Gateway Sim 2026",
    code: "ARTEMIS-GW",
    description: "Simulación de estancia en la estación Gateway en órbita lunar.",
    status: "active"
  },
  {
    name: "Mars Transit Analog 2027",
    code: "MARS-TRANSIT",
    description: "Análogo de tránsito prolongado a Marte con tripulación reducida.",
    status: "active"
  }
].each do |attrs|
  missions[attrs[:code]] = Mission.create!(attrs)
end

puts "Creando catálogo de logros…"
GamificationService::CATALOG.each do |config|
  Achievement.find_or_create_by!(name: config[:name]) do |achievement|
    achievement.description = config[:description]
    achievement.points = config[:points]
  end
end

# Series de 7 días por indicador. Los tres primeros días solo tienen 4
# indicadores para que las gráficas tengan tendencia sin completar racha de 7.
# El índice 6 corresponde a HOY. nil = sin medición ese día.
profiles = {
  critical: {
    "blood_pressure_systolic" => [ 122, 128, 132, 136, 145, 128, 142 ],
    "blood_pressure_diastolic" => [ nil, nil, nil, 86, 92, 82, 94 ],
    "heart_rate" => [ 92, 98, 94, 88, 110, 84, 76 ],
    "blood_glucose" => [ nil, nil, nil, 160, 255, 120, 265 ],
    "body_temperature" => [ nil, nil, nil, 37.0, 38.2, 37.1, 37.2 ],
    "sleep_hours" => [ 5.8, 5.5, 6.2, 6.5, 3.5, 6.0, 5.5 ],
    "mood_score" => [ 5, 6, 6, 7, 4, 6, 7 ]
  },
  watch: {
    "blood_pressure_systolic" => [ 118, 124, 130, 128, 134, 126, 132 ],
    "blood_pressure_diastolic" => [ nil, nil, nil, 78, 84, 80, 86 ],
    "heart_rate" => [ 72, 80, 76, 82, 96, 74, 88 ],
    "blood_glucose" => [ nil, nil, nil, 110, 165, 118, 175 ],
    "body_temperature" => [ nil, nil, nil, 36.8, 37.4, 36.9, 37.1 ],
    "sleep_hours" => [ 6.5, 6.0, 5.8, 6.2, 5.0, 6.4, 5.5 ],
    "mood_score" => [ 7, 6, 7, 6, 5, 7, 6 ]
  },
  healthy: {
    "blood_pressure_systolic" => [ 118, 120, 116, 119, 121, 118, 117 ],
    "blood_pressure_diastolic" => [ nil, nil, nil, 76, 78, 74, 75 ],
    "heart_rate" => [ 68, 72, 70, 66, 74, 69, 71 ],
    "blood_glucose" => [ nil, nil, nil, 98, 105, 92, 100 ],
    "body_temperature" => [ nil, nil, nil, 36.6, 36.7, 36.5, 36.8 ],
    "sleep_hours" => [ 7.2, 7.0, 7.5, 7.1, 6.8, 7.4, 7.3 ],
    "mood_score" => [ 8, 8, 9, 8, 8, 9, 8 ]
  },
  psych: {
    "blood_pressure_systolic" => [ 120, 122, 118, 124, 126, 121, 123 ],
    "blood_pressure_diastolic" => [ nil, nil, nil, 78, 80, 76, 79 ],
    "heart_rate" => [ 70, 74, 72, 76, 82, 71, 78 ],
    "blood_glucose" => [ nil, nil, nil, 102, 110, 96, 105 ],
    "body_temperature" => [ nil, nil, nil, 36.7, 36.9, 36.6, 36.8 ],
    "sleep_hours" => [ 6.2, 5.8, 5.5, 4.8, 3.2, 5.0, 3.5 ],
    "mood_score" => [ 6, 5, 5, 4, 2, 3, 3 ]
  }
}

# Chequeo diario (riesgos NASA HRP / CSA) por perfil.
daily_profiles = {
  critical: {
    bone_density_loss_percent: 1.8, co2_level: 2_200, stress_level: 8, calories_intake: 1_500,
    vision_blurred: true, dizziness_reported: true, skin_rash: true
  },
  watch: {
    bone_density_loss_percent: 1.1, co2_level: 1_200, stress_level: 6, calories_intake: 2_000,
    vision_blurred: false, dizziness_reported: true, skin_rash: false
  },
  healthy: {
    bone_density_loss_percent: 0.4, co2_level: 650, stress_level: 3, calories_intake: 2_500,
    vision_blurred: false, dizziness_reported: false, skin_rash: false
  },
  psych: {
    bone_density_loss_percent: 0.3, co2_level: 700, stress_level: 9, calories_intake: 1_700,
    vision_blurred: false, dizziness_reported: false, skin_rash: false
  }
}

journal_prompts = {
  critical: "Día difícil: visión borrosa y mareos tras el ejercicio. He avisado al equipo y estoy pendiente de la prueba visual.",
  watch: "Sesión de ejercicio completada. Un poco de mareo al levantarme rápido, pero se ha pasado con hidratación.",
  healthy: "Buen ánimo y rutina estable. He llamado a casa y he dormido mejor.",
  psych: "Me cuesta desconectar del trabajo. El confinamiento pesa hoy; escribir aquí ayuda un poco."
}

# Estudios NASA: Immune Biomarkers, CIPHER, SANS/B-Complex y ARCHeR.
research_profiles = {
  critical: {
    saliva_sample_taken: true, virus_reactivation_suspected: true,
    calcium_isotopes_level: 7.8, telomere_length: 3.2, spatial_cognition_score: 35,
    vestibular_test_passed: false, vision_test_performed: false, oct_scan_result: "abnormal",
    b_complex_supplement_taken: false, actigraphy_device_synced: false,
    cognitive_performance_survey_score: 28
  },
  watch: {
    saliva_sample_taken: true, virus_reactivation_suspected: false,
    calcium_isotopes_level: 8.6, telomere_length: 4.6, spatial_cognition_score: 62,
    vestibular_test_passed: true, vision_test_performed: true, oct_scan_result: "normal",
    b_complex_supplement_taken: true, actigraphy_device_synced: true,
    cognitive_performance_survey_score: 70
  },
  healthy: {
    saliva_sample_taken: true, virus_reactivation_suspected: false,
    calcium_isotopes_level: 9.2, telomere_length: 6.2, spatial_cognition_score: 85,
    vestibular_test_passed: true, vision_test_performed: true, oct_scan_result: "normal",
    b_complex_supplement_taken: true, actigraphy_device_synced: true,
    cognitive_performance_survey_score: 88
  },
  psych: {
    saliva_sample_taken: false, virus_reactivation_suspected: false,
    calcium_isotopes_level: 8.9, telomere_length: 5.1, spatial_cognition_score: 55,
    vestibular_test_passed: true, vision_test_performed: true, oct_scan_result: "normal",
    b_complex_supplement_taken: true, actigraphy_device_synced: false,
    cognitive_performance_survey_score: 35
  }
}

biomarker_profiles = {
  critical: { sample_type: "saliva_dry", notes: "Muestra prioritaria por sospecha de reactivación viral." },
  watch: { sample_type: "blood", notes: "Análisis de biomarcadores inmunes de rutina." },
  healthy: { sample_type: "saliva_dry", notes: "Muestra de saliva seca para Standard Measures." },
  psych: { sample_type: "urine", notes: "Muestra para panel metabólico y de estrés." }
}

# Chequeo de síntomas y métricas de nutrición/contacto social.
symptom_profiles = {
  critical: { rash_or_hives: true, vision_changes: true, dizziness_nausea: true },
  watch: { rash_or_hives: false, vision_changes: false, dizziness_nausea: true },
  healthy: { rash_or_hives: false, vision_changes: false, dizziness_nausea: false },
  psych: { rash_or_hives: false, vision_changes: false, dizziness_nausea: false }
}

wellness_profiles = {
  critical: { meals_completed_percent: 35, social_contact_minutes: 5 },
  watch: { meals_completed_percent: 70, social_contact_minutes: 20 },
  healthy: { meals_completed_percent: 95, social_contact_minutes: 45 },
  psych: { meals_completed_percent: 55, social_contact_minutes: 4 }
}

reaction_profiles = { critical: 620, watch: 480, healthy: 350, psych: 540 }

astronaut_specs = [
  { name: "Ana Ríos", mission: "ARTEMIS-GW", profile: :critical, destination: "iss" },
  { name: "Carlos Méndez", mission: "ARTEMIS-GW", profile: :watch, destination: "moon" },
  { name: "Yuki Tanaka", mission: "MARS-TRANSIT", profile: :healthy, destination: "mars" },
  { name: "Léa Dubois", mission: "MARS-TRANSIT", profile: :psych, destination: "mars" }
]

puts "Creando astronautas y lecturas…"
astronaut_specs.each do |spec|
  astronaut = Astronaut.create!(name: spec[:name], mission: missions.fetch(spec[:mission]), destination: spec[:destination])
  profile = profiles.fetch(spec[:profile])
  created = 0

  # Línea base pre-vuelo de ejemplo: el corazón en reposo en Tierra.
  # La lectura actual de Ana (76 bpm) queda > 20 % por encima y se marca amarilla.
  if spec[:profile] == :critical
    astronaut.health_readings.create!(
      indicator_type: "heart_rate", value: 60, is_baseline: true,
      measured_at: Time.current - 8.days
    )
  end

  profile.each do |indicator_type, series|
    indicator_offset = HealthReading::INDICATOR_TYPES.index(indicator_type)

    series.each_with_index do |value, day_index|
      next if value.nil?

      days_ago = 6 - day_index
      measured_at = Time.zone.now.beginning_of_day - days_ago.days + 8.hours + indicator_offset.minutes

      astronaut.health_readings.create!(
        indicator_type: indicator_type,
        value: value,
        measured_at: measured_at
      )
      created += 1
    end
  end

  astronaut.daily_checks.create!(checked_on: Date.current, **daily_profiles.fetch(spec[:profile]))
  astronaut.symptom_checks.create!(checked_on: Date.current, **symptom_profiles.fetch(spec[:profile]))

  wellness = wellness_profiles.fetch(spec[:profile])
  astronaut.health_readings.create!(
    indicator_type: "meals_completed_percent", value: wellness[:meals_completed_percent],
    meals_completed_percent: wellness[:meals_completed_percent], measured_at: Time.current
  )
  astronaut.health_readings.create!(
    indicator_type: "social_contact_minutes", value: wellness[:social_contact_minutes],
    social_contact_minutes: wellness[:social_contact_minutes], measured_at: Time.current
  )
  astronaut.health_readings.create!(
    indicator_type: "reaction_time", value: reaction_profiles.fetch(spec[:profile]),
    reaction_time_ms: reaction_profiles.fetch(spec[:profile]), measured_at: Time.current
  )

  # Evaluación de hoy + una línea base para poder simular el protocolo SANS
  # de "prueba visual vencida" (más de 7 días sin realizarla).
  if spec[:profile] == :critical
    astronaut.research_assessments.create!(
      assessed_on: Date.current - 10.days,
      vision_test_performed: true
    )
  end
  astronaut.research_assessments.create!(
    assessed_on: Date.current,
    **research_profiles.fetch(spec[:profile])
  )

  astronaut.biomarker_samples.create!(
    collected_at: Time.current - 4.hours,
    **biomarker_profiles.fetch(spec[:profile])
  )

  astronaut.journal_entries.create!(content: journal_prompts.fetch(spec[:profile]))
  astronaut.pre_eva_checks.create!(
    o2_ok: true,
    pressure_ok: true,
    fatigue_ok: spec[:profile] != :critical,
    egress_fitness_completed: %i[watch healthy].include?(spec[:profile]),
    checked_at: Time.current
  )

  awarded = GamificationService.new(astronaut).call
  puts "  → #{astronaut.name} (#{astronaut.mission.code}): #{created} lecturas, #{astronaut.total_points} pts"
  puts "     Logros: #{awarded.map(&:name).join(', ')}" if awarded.any?
end

puts
puts "Listo. Misiones: #{Mission.count} · Astronautas: #{Astronaut.count} · Lecturas: #{HealthReading.count} · Chequeos: #{DailyCheck.count} · Síntomas: #{SymptomCheck.count} · Estudios: #{ResearchAssessment.count} · Muestras: #{BiomarkerSample.count}"
puts "Abre http://localhost:3000 y usa el selector de misión/astronauta."
