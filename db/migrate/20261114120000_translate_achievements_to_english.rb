class TranslateAchievementsToEnglish < ActiveRecord::Migration[8.1]
  TRANSLATIONS = [
    {
      old_name: "Primer registro",
      new_name: "First reading",
      old_description: "Registraste tu primera medición de salud en la herramienta.",
      new_description: "You logged your first health measurement in the tool."
    },
    {
      old_name: "Chequeo diario completo",
      new_name: "Complete daily check",
      old_description: "Completaste todos los indicadores en un mismo día.",
      new_description: "You completed all indicators on the same day."
    },
    {
      old_name: "Racha de 3 días",
      new_name: "3-day streak",
      old_description: "Tres días consecutivos con chequeo completo.",
      new_description: "Three consecutive days with a complete check."
    },
    {
      old_name: "Racha de 7 días",
      new_name: "7-day streak",
      old_description: "Una semana completa de monitorización constante.",
      new_description: "A full week of steady monitoring."
    },
    {
      old_name: "Día en verde",
      new_name: "Green day",
      old_description: "Todos tus indicadores del día estuvieron en rango verde.",
      new_description: "All of your indicators were in the green range today."
    }
  ].freeze

  def up
    say_with_time "Translating achievement catalog to English" do
      TRANSLATIONS.each do |translation|
        execute <<~SQL.squish
          UPDATE achievements
          SET name = #{connection.quote(translation[:new_name])},
              description = #{connection.quote(translation[:new_description])},
              updated_at = NOW()
          WHERE name = #{connection.quote(translation[:old_name])}
        SQL
      end
    end
  end

  def down
    say_with_time "Restoring achievement catalog to Spanish" do
      TRANSLATIONS.each do |translation|
        execute <<~SQL.squish
          UPDATE achievements
          SET name = #{connection.quote(translation[:old_name])},
              description = #{connection.quote(translation[:old_description])},
              updated_at = NOW()
          WHERE name = #{connection.quote(translation[:new_name])}
        SQL
      end
    end
  end
end
