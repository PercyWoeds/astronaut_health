class CreateBodyZones < ActiveRecord::Migration[8.1]
  def change
    create_table :body_zones do |t|
      t.string :name, null: false
      t.text :description
      t.jsonb :related_indicators, null: false, default: []

      t.timestamps
    end
  end
end
