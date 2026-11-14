class CreateResearchAssessments < ActiveRecord::Migration[8.1]
  def change
    create_table :research_assessments do |t|
      t.references :astronaut, null: false, foreign_key: true
      t.date :assessed_on, null: false

      # Immune Biomarkers (Artemis / Standard Measures)
      t.boolean :saliva_sample_taken, null: false, default: false
      t.boolean :virus_reactivation_suspected, null: false, default: false

      # CIPHER: Bone Health, Telomeres, Spatial Cognition, Vestibular Health
      t.float :calcium_isotopes_level
      t.float :telomere_length
      t.integer :spatial_cognition_score
      t.boolean :vestibular_test_passed, null: false, default: false

      # SANS / B-Complex
      t.boolean :vision_test_performed, null: false, default: false
      t.string :oct_scan_result, null: false, default: "normal"
      t.boolean :b_complex_supplement_taken, null: false, default: false

      # ARCHeR
      t.boolean :actigraphy_device_synced, null: false, default: false
      t.integer :cognitive_performance_survey_score

      t.timestamps
    end

    add_index :research_assessments, [ :astronaut_id, :assessed_on ], unique: true
  end
end
