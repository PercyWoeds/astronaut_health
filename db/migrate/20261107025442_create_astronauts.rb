class CreateAstronauts < ActiveRecord::Migration[8.1]
  def change
    create_table :astronauts do |t|
      t.string :name, null: false
      t.string :mission, null: false, default: "Misión de prueba"

      t.timestamps
    end
  end
end
