class CreateAstronautAchievements < ActiveRecord::Migration[8.1]
  def change
    create_table :astronaut_achievements do |t|
      t.references :astronaut, null: false, foreign_key: true
      t.references :achievement, null: false, foreign_key: true
      t.datetime :awarded_at, null: false

      t.timestamps

      t.index [ :astronaut_id, :achievement_id ], unique: true
    end
  end
end
