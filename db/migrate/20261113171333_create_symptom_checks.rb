class CreateSymptomChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :symptom_checks do |t|
      t.references :astronaut, null: false, foreign_key: true
      t.date :checked_on, null: false
      t.boolean :rash_or_hives, null: false, default: false
      t.boolean :vision_changes, null: false, default: false
      t.boolean :dizziness_nausea, null: false, default: false

      t.timestamps
    end

    add_index :symptom_checks, [ :astronaut_id, :checked_on ], unique: true
  end
end
