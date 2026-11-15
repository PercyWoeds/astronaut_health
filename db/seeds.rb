# Demo data for the hackathon.
# Run with: bin/rails db:seed
# The script is destructive for demo data: it clears missions, astronauts,
# readings and achievements before recreating them. It does not touch BodyZone
# (global catalog).

puts "Clearing demo data…"
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

puts "Creating indicator catalog…"
Indicator.seed_catalog!

puts "Creating body zones…"
zones = [
  {
    name: "head",
    description: "Head and neuropsychological state: thermoregulation, mood and cognitive fatigue.",
    related_indicators: %w[body_temperature mood_score sleep_hours reaction_time]
  },
  {
    name: "chest",
    description: "Chest: cardiovascular system. Blood pressure and resting heart rate.",
    related_indicators: %w[blood_pressure_systolic blood_pressure_diastolic heart_rate]
  },
  {
    name: "abdomen",
    description: "Abdomen: metabolism and glycemic control during the mission.",
    related_indicators: %w[blood_glucose meals_completed_percent hydration_ml]
  },
  {
    name: "limbs",
    description: "Limbs: physical performance, muscle recovery and sleep hours.",
    related_indicators: %w[sleep_hours muscle_performance balance]
  }
]

zones.each do |attrs|
  BodyZone.find_or_initialize_by(name: attrs[:name]).update!(attrs)
end

puts "Creating missions…"
missions = {}
[
  {
    name: "Artemis · Gateway Sim 2026",
    code: "ARTEMIS-GW",
    description: "Simulated stay aboard the Gateway station in lunar orbit.",
    status: "active"
  },
  {
    name: "Mars Transit Analog 2027",
    code: "MARS-TRANSIT",
    description: "Long-duration Mars transit analog with a reduced crew.",
    status: "active"
  }
].each do |attrs|
  missions[attrs[:code]] = Mission.create!(attrs)
end

puts "Creating achievement catalog…"
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
    "blood_pressure_systolic" => [ 118, 122, 126, 130, 138, 128, 145 ],
    "blood_pressure_diastolic" => [ nil, nil, nil, 78, 84, 80, 92 ],
    "heart_rate" => [ 68, 72, 70, 74, 76, 72, 76 ],
    "blood_glucose" => [ nil, nil, nil, 98, 110, 96, 105 ],
    "body_temperature" => [ nil, nil, nil, 36.7, 36.9, 36.6, 36.8 ],
    "sleep_hours" => [ 7.0, 6.8, 7.2, 7.1, 6.9, 7.3, 7.0 ],
    "mood_score" => [ 8, 7, 8, 8, 7, 8, 8 ]
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
    "blood_pressure_systolic" => [ 118, 117, 116, 118, 119, 116, 117 ],
    "blood_pressure_diastolic" => [ nil, nil, nil, 76, 78, 74, 75 ],
    "heart_rate" => [ 68, 72, 70, 66, 74, 69, 71 ],
    "blood_glucose" => [ nil, nil, nil, 98, 105, 92, 100 ],
    "body_temperature" => [ nil, nil, nil, 36.6, 36.7, 36.5, 36.8 ],
    "sleep_hours" => [ 7.2, 7.0, 7.5, 7.1, 6.8, 7.4, 7.3 ],
    "mood_score" => [ 8, 8, 9, 8, 8, 9, 8 ]
  },
  psych: {
    "blood_pressure_systolic" => [ 118, 120, 118, 122, 124, 119, 121 ],
    "blood_pressure_diastolic" => [ nil, nil, nil, 76, 78, 74, 77 ],
    "heart_rate" => [ 70, 74, 72, 76, 82, 71, 78 ],
    "blood_glucose" => [ nil, nil, nil, 102, 110, 96, 105 ],
    "body_temperature" => [ nil, nil, nil, 36.7, 36.9, 36.6, 36.8 ],
    "sleep_hours" => [ 6.5, 6.0, 5.8, 6.2, 5.5, 6.0, 5.5 ],
    "mood_score" => [ 7, 6, 6, 5, 5, 6, 5 ]
  }
}

# Chequeo diario (riesgos NASA HRP / CSA) por perfil.
daily_profiles = {
  critical: {
    bone_density_loss_percent: 1.1, co2_level: 1_200, stress_level: 6, calories_intake: 2_000,
    vision_blurred: false, dizziness_reported: false, skin_rash: false
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
    bone_density_loss_percent: 0.5, co2_level: 800, stress_level: 6, calories_intake: 2_200,
    vision_blurred: false, dizziness_reported: false, skin_rash: false
  }
}

journal_prompts = {
  critical: "Chest felt a little tight after exercise. I reported it to the team and I am resting while they review the reading.",
  watch: "Exercise session completed. A bit of dizziness when standing up quickly, but it passed with hydration.",
  healthy: "Good mood and a stable routine. I called home and slept better.",
  psych: "A quiet day in confinement. I called home and wrote down a short plan for tomorrow to stay focused."
}

# Estudios NASA: Immune Biomarkers, CIPHER, SANS/B-Complex y ARCHeR.
research_profiles = {
  critical: {
    saliva_sample_taken: true, virus_reactivation_suspected: false,
    calcium_isotopes_level: 8.6, telomere_length: 4.6, spatial_cognition_score: 62,
    vision_test_performed: true, oct_scan_result: "normal",
    b_complex_supplement_taken: true, actigraphy_device_synced: true,
    cognitive_performance_survey_score: 70
  },
  watch: {
    saliva_sample_taken: true, virus_reactivation_suspected: false,
    calcium_isotopes_level: 8.6, telomere_length: 4.6, spatial_cognition_score: 62,
    vision_test_performed: true, oct_scan_result: "normal",
    b_complex_supplement_taken: true, actigraphy_device_synced: true,
    cognitive_performance_survey_score: 70
  },
  healthy: {
    saliva_sample_taken: true, virus_reactivation_suspected: false,
    calcium_isotopes_level: 9.2, telomere_length: 6.2, spatial_cognition_score: 85,
    vision_test_performed: true, oct_scan_result: "normal",
    b_complex_supplement_taken: true, actigraphy_device_synced: true,
    cognitive_performance_survey_score: 88
  },
  psych: {
    saliva_sample_taken: true, virus_reactivation_suspected: false,
    calcium_isotopes_level: 8.9, telomere_length: 5.1, spatial_cognition_score: 62,
    vision_test_performed: true, oct_scan_result: "normal",
    b_complex_supplement_taken: true, actigraphy_device_synced: true,
    cognitive_performance_survey_score: 70
  }
}

biomarker_profiles = {
  critical: { sample_type: "blood", notes: "Routine immune biomarker panel." },
  watch: { sample_type: "blood", notes: "Routine immune biomarker panel." },
  healthy: { sample_type: "saliva_dry", notes: "Dry saliva sample for Standard Measures." },
  psych: { sample_type: "urine", notes: "Sample for metabolic and stress panel." }
}

# Chequeo de síntomas y métricas de nutrición/contacto social.
symptom_profiles = {
  critical: { rash_or_hives: false, vision_changes: false, dizziness_nausea: false },
  watch: { rash_or_hives: false, vision_changes: false, dizziness_nausea: true },
  healthy: { rash_or_hives: false, vision_changes: false, dizziness_nausea: false },
  psych: { rash_or_hives: false, vision_changes: false, dizziness_nausea: false }
}

wellness_profiles = {
  critical: { meals_completed_percent: 85, social_contact_minutes: 30 },
  watch: { meals_completed_percent: 70, social_contact_minutes: 20 },
  healthy: { meals_completed_percent: 95, social_contact_minutes: 45 },
  psych: { meals_completed_percent: 75, social_contact_minutes: 20 }
}

reaction_profiles = { critical: 400, watch: 480, healthy: 350, psych: 480 }

astronaut_specs = [
  { name: "Ana Ríos", mission: "ARTEMIS-GW", profile: :critical, destination: "moon" },
  { name: "Carlos Méndez", mission: "ARTEMIS-GW", profile: :watch, destination: "moon" },
  { name: "Yuki Tanaka", mission: "MARS-TRANSIT", profile: :healthy, destination: "mars" },
  { name: "Léa Dubois", mission: "MARS-TRANSIT", profile: :psych, destination: "mars" }
]

puts "Creating astronauts and readings…"
astronaut_specs.each do |spec|
  astronaut = Astronaut.create!(name: spec[:name], mission: missions.fetch(spec[:mission]), destination: spec[:destination])
  profile = profiles.fetch(spec[:profile])
  created = 0

  # Pre-flight baseline: resting heart rate on Earth.
  # Ana's current reading (76 bpm) is > 20 % above baseline and is marked yellow.
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
      measured_at = [ measured_at, Time.current - 1.minute ].min

      astronaut.health_readings.create!(
        indicator_type: indicator_type,
        value: value,
        data_origin: "simulated",
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
    meals_completed_percent: wellness[:meals_completed_percent], data_origin: "simulated", measured_at: Time.current
  )
  astronaut.health_readings.create!(
    indicator_type: "social_contact_minutes", value: wellness[:social_contact_minutes],
    social_contact_minutes: wellness[:social_contact_minutes], data_origin: "simulated", measured_at: Time.current
  )
  astronaut.health_readings.create!(
    indicator_type: "reaction_time", value: reaction_profiles.fetch(spec[:profile]),
    reaction_time_ms: reaction_profiles.fetch(spec[:profile]), data_origin: "simulated", measured_at: Time.current
  )

  # Experimental indicators: hydration, training-load proxy and balance self-check.
  # Clamped to today so gamification streaks never depend on the local clock.
  experimental_times = [ 20, 19, 18 ].map do |hour|
    [ Time.current - 1.minute, Date.current.beginning_of_day + hour.hours ].min
  end

  astronaut.health_readings.create!(
    indicator_type: "hydration_ml", value: 2_400, thirst_score: 3,
    data_origin: "simulated", measured_at: experimental_times.fetch(0)
  )
  astronaut.health_readings.create!(
    indicator_type: "muscle_performance", value: 55,
    resistance_minutes: 30, aerobic_minutes: 25,
    perceived_exertion: 6, muscle_soreness: 2,
    data_origin: "simulated", measured_at: experimental_times.fetch(1)
  )
  astronaut.health_readings.create!(
    indicator_type: "balance", value: 1, balance_episodes: 0,
    balance_environment: "earth", data_origin: "simulated", measured_at: experimental_times.fetch(2)
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
    fatigue_ok: true,
    egress_fitness_completed: true,
    checked_at: Time.current
  )

  awarded = GamificationService.new(astronaut).call
  pending = MeasurementReminders.call(astronaut)
  puts "  → #{astronaut.name} (#{astronaut.mission.code}): #{created} readings, #{astronaut.total_points} pts, #{pending.size} pending"
  puts "     Achievements: #{awarded.map(&:name).join(', ')}" if awarded.any?
end

puts
puts "Done. Missions: #{Mission.count} · Astronauts: #{Astronaut.count} · Readings: #{HealthReading.count} · Checks: #{DailyCheck.count} · Symptoms: #{SymptomCheck.count} · Studies: #{ResearchAssessment.count} · Samples: #{BiomarkerSample.count}"
puts "Open http://localhost:3000 and use the mission/astronaut selector."
