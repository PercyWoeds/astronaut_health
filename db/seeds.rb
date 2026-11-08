# Datos de demostración para la hackathon.
# Ejecutar con: bin/rails db:seed
# El script es destructivo con los datos demo: limpia misiones, astronautas,
# lecturas y logros antes de recrearlos. No toca BodyZone (catálogo global).

puts "Limpiando datos demo…"
AstronautAchievement.delete_all
HealthReading.delete_all
Astronaut.delete_all
Mission.delete_all
Achievement.delete_all

puts "Creando zonas corporales…"
zones = [
  {
    name: "head",
    description: "Cabeza y estado neuropsicológico: termorregulación, estado de ánimo y fatiga cognitiva.",
    related_indicators: %w[body_temperature mood_score sleep_hours]
  },
  {
    name: "chest",
    description: "Tórax: sistema cardiovascular. Presión arterial y frecuencia cardíaca en reposo.",
    related_indicators: %w[blood_pressure_systolic blood_pressure_diastolic heart_rate]
  },
  {
    name: "abdomen",
    description: "Abdomen: metabolismo y control glucémico durante la misión.",
    related_indicators: %w[blood_glucose]
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

astronaut_specs = [
  { name: "Ana Ríos", mission: "ARTEMIS-GW", profile: :critical },
  { name: "Carlos Méndez", mission: "ARTEMIS-GW", profile: :watch },
  { name: "Yuki Tanaka", mission: "MARS-TRANSIT", profile: :healthy },
  { name: "Léa Dubois", mission: "MARS-TRANSIT", profile: :psych }
]

puts "Creando astronautas y lecturas…"
astronaut_specs.each do |spec|
  astronaut = Astronaut.create!(name: spec[:name], mission: missions.fetch(spec[:mission]))
  profile = profiles.fetch(spec[:profile])
  created = 0

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

  awarded = GamificationService.new(astronaut).call
  puts "  → #{astronaut.name} (#{astronaut.mission.code}): #{created} lecturas, #{astronaut.total_points} pts"
  puts "     Logros: #{awarded.map(&:name).join(', ')}" if awarded.any?
end

puts
puts "Listo. Misiones: #{Mission.count} · Astronautas: #{Astronaut.count} · Lecturas: #{HealthReading.count}"
puts "Abre http://localhost:3000 y usa el selector de misión/astronauta."
