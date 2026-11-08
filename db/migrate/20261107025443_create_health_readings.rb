class CreateHealthReadings < ActiveRecord::Migration[8.1]
  def change
    create_table :health_readings do |t|
      t.references :astronaut, null: false, foreign_key: true
      t.string  :indicator_type, null: false
      t.float   :value, null: false
      t.string  :unit, null: false
      t.datetime :measured_at, null: false
      t.string :status, null: false, default: "green"

      t.timestamps

      t.index [ :astronaut_id, :indicator_type, :measured_at ], name: "idx_readings_by_astro_indicator_time"
    end
  end
end
