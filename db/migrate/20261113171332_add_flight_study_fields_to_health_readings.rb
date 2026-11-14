class AddFlightStudyFieldsToHealthReadings < ActiveRecord::Migration[8.1]
  def change
    add_column :health_readings, :is_baseline, :boolean, null: false, default: false
    add_column :health_readings, :reaction_time_ms, :integer
    add_column :health_readings, :meals_completed_percent, :integer
    add_column :health_readings, :social_contact_minutes, :integer

    add_index :health_readings, [ :astronaut_id, :indicator_type, :is_baseline ],
              name: "idx_readings_baseline_lookup"
  end
end
