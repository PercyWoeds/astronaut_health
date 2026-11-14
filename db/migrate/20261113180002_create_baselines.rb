class CreateBaselines < ActiveRecord::Migration[8.1]
  def change
    create_table :baselines do |t|
      t.references :astronaut, null: false, foreign_key: true
      t.references :indicator, null: false, foreign_key: true
      t.float :mean, null: false
      t.float :std, null: false
      t.integer :samples, null: false, default: 0
      t.string :source, null: false, default: "pre-flight"

      t.timestamps
    end

    add_index :baselines, [ :astronaut_id, :indicator_id ], unique: true
  end
end
