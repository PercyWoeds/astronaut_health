class CreateBiomarkerSamples < ActiveRecord::Migration[8.1]
  def change
    create_table :biomarker_samples do |t|
      t.references :astronaut, null: false, foreign_key: true
      t.string :sample_type, null: false
      t.datetime :collected_at, null: false
      t.text :notes

      t.timestamps
    end

    add_index :biomarker_samples, [ :astronaut_id, :collected_at ]
  end
end
