class AddMissionToAstronauts < ActiveRecord::Migration[8.1]
  # Migra el antiguo campo astronauts.mission (string) a una entidad Mission.
  # Si ya existen astronautas, se agrupan en una misión "importada" para no
  # perder datos; después los seeds recrean misiones y astronautas demo.
  def up
    add_reference :astronauts, :mission, foreign_key: true

    if select_value("SELECT COUNT(*) FROM astronauts").to_i.positive?
      execute <<~SQL
        INSERT INTO missions (name, code, description, status, created_at, updated_at)
        VALUES ('Misión importada', 'IMPORTED', 'Creada automáticamente al migrar astronautas existentes', 'active', NOW(), NOW())
      SQL

      execute "UPDATE astronauts SET mission_id = (SELECT id FROM missions WHERE code = 'IMPORTED')"
    end

    change_column_null :astronauts, :mission_id, false
    remove_column :astronauts, :mission, :string
  end

  def down
    add_column :astronauts, :mission, :string

    execute <<~SQL
      UPDATE astronauts
      SET mission = COALESCE((SELECT name FROM missions WHERE missions.id = astronauts.mission_id), 'Misión')
    SQL

    remove_reference :astronauts, :mission, foreign_key: true
  end
end
