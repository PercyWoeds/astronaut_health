class AddDestinationToAstronauts < ActiveRecord::Migration[8.1]
  def change
    add_column :astronauts, :destination, :string, default: "iss", null: false
  end
end
