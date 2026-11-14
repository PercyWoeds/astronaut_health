class CreateIndicators < ActiveRecord::Migration[8.1]
  def change
    create_table :indicators do |t|
      t.string :key, null: false
      t.string :axis, null: false
      t.string :unit, null: false
      t.string :bad_direction, null: false
      t.float :abs_min
      t.float :abs_max
      t.float :yellow_min
      t.float :yellow_max
      t.float :red_min
      t.float :red_max
      t.text :hazards
      t.string :source_url
      t.integer :frequency_days, default: 1, null: false

      t.timestamps
    end

    add_index :indicators, :key, unique: true
  end
end
