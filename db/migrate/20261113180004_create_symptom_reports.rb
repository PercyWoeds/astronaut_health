class CreateSymptomReports < ActiveRecord::Migration[8.1]
  def change
    create_table :symptom_reports do |t|
      t.references :astronaut, null: false, foreign_key: true
      t.boolean :rash, default: false, null: false
      t.boolean :vision_change, default: false, null: false
      t.boolean :dizziness, default: false, null: false
      t.text :note

      t.timestamps
    end
  end
end
