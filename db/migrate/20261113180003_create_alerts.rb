class CreateAlerts < ActiveRecord::Migration[8.1]
  def change
    create_table :alerts do |t|
      t.references :astronaut, null: false, foreign_key: true
      t.references :indicator, null: false, foreign_key: true
      t.string :level, null: false
      t.string :basis, null: false
      t.string :status, null: false, default: "open"
      t.text :note

      t.timestamps
    end

    add_index :alerts, [ :astronaut_id, :status ]
  end
end
