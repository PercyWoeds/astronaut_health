class AddOriginAndExperimentalFieldsToHealthReadings < ActiveRecord::Migration[8.1]
  def change
    add_column :health_readings, :data_origin, :string, default: "manual", null: false
    add_column :health_readings, :thirst_score, :integer
    add_column :health_readings, :resistance_minutes, :integer
    add_column :health_readings, :aerobic_minutes, :integer
    add_column :health_readings, :perceived_exertion, :integer
    add_column :health_readings, :muscle_soreness, :integer
    add_column :health_readings, :external_load_kg, :float
    add_column :health_readings, :external_reps, :integer
    add_column :health_readings, :balance_episodes, :integer
    add_column :health_readings, :balance_test_performed, :boolean, default: false, null: false
    add_column :health_readings, :balance_test_supported, :boolean, default: false, null: false
    add_column :health_readings, :balance_environment, :string
  end
end
