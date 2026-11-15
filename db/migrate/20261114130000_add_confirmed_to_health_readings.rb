class AddConfirmedToHealthReadings < ActiveRecord::Migration[8.1]
  def change
    add_column :health_readings, :confirmed, :boolean, default: false, null: false
  end
end
