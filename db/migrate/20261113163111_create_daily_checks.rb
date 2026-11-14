class CreateDailyChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_checks do |t|
      t.references :astronaut, null: false, foreign_key: true
      t.date :checked_on, null: false

      # Riesgos fisiológicos NASA HRP / CSA
      t.float :bone_density_loss_percent, null: false, default: 0.0
      t.integer :co2_level, null: false, default: 0
      t.integer :stress_level, null: false, default: 1
      t.integer :calories_intake, null: false, default: 0
      t.boolean :vision_blurred, null: false, default: false
      t.boolean :dizziness_reported, null: false, default: false
      t.boolean :skin_rash, null: false, default: false

      t.timestamps
    end

    add_index :daily_checks, [ :astronaut_id, :checked_on ], unique: true
  end
end
