class CreatePreEvaChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :pre_eva_checks do |t|
      t.references :astronaut, null: false, foreign_key: true
      t.boolean :o2_ok, null: false, default: false
      t.boolean :pressure_ok, null: false, default: false
      t.boolean :fatigue_ok, null: false, default: false
      t.datetime :checked_at, null: false

      t.timestamps
    end
  end
end
