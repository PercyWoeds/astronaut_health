# Gamificación básica: desbloquea logros cuando el astronauta mantiene
# constancia en sus chequeos. Los logros se crean de forma idempotente para
# que llamar al servicio varias veces no duplique puntos.
class GamificationService
  # Catálogo de logros disponibles.
  CATALOG = [
    { key: "first_reading", name: "Primer registro", points: 10,
      description: "Registraste tu primera medición de salud en la herramienta." },
    { key: "daily_checkup", name: "Chequeo diario completo", points: 50,
      description: "Completaste todos los indicadores en un mismo día." },
    { key: "streak_3", name: "Racha de 3 días", points: 100,
      description: "Tres días consecutivos con chequeo completo." },
    { key: "streak_7", name: "Racha de 7 días", points: 250,
      description: "Una semana completa de monitorización constante." },
    { key: "perfect_day", name: "Día en verde", points: 75,
      description: "Todos tus indicadores del día estuvieron en rango verde." }
  ].freeze

  attr_reader :astronaut, :date

  def initialize(astronaut, date: Date.current)
    @astronaut = astronaut
    @date = date
  end

  # Devuelve los logros NUEVOS obtenidos en esta llamada.
  def call
    awarded = []

    awarded << award("first_reading") if astronaut.health_readings.exists?

    if daily_checkup_complete?
      awarded << award("daily_checkup")
      awarded << award("perfect_day") if perfect_day?
      awarded << award("streak_3") if streak_days >= 3
      awarded << award("streak_7") if streak_days >= 7
    end

    awarded.compact
  end

  # Días consecutivos (hasta hoy) con todos los indicadores registrados.
  def streak_days
    count = 0
    cursor = date
    while daily_checkup_complete?(cursor)
      count += 1
      cursor -= 1
      break if count >= 365
    end
    count
  end

  private

  def daily_checkup_complete?(day = date)
    types = astronaut.health_readings.on_day(day).distinct.pluck(:indicator_type)
    (HealthReading::DAILY_CHECKUP_INDICATORS - types).empty?
  end

  def perfect_day?(day = date)
    readings = astronaut.health_readings.on_day(day).recent_first.to_a
    latest = readings.each_with_object({}) { |r, memo| memo[r.indicator_type] ||= r }
    HealthReading::DAILY_CHECKUP_INDICATORS.all? { |type| latest[type]&.status == "green" }
  end

  def award(key)
    config = CATALOG.find { |item| item[:key] == key }
    return nil unless config

    achievement = Achievement.find_or_create_by!(name: config[:name]) do |a|
      a.description = config[:description]
      a.points = config[:points]
    end

    # Solo devolvemos el logro si es nuevo; find_or_initialize evita
    # notificar una y otra vez logros ya conseguidos.
    join = astronaut.astronaut_achievements.find_or_initialize_by(achievement: achievement)
    return nil if join.persisted?

    join.save!
    achievement
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
