class CreateAchievements < ActiveRecord::Migration[8.1]
  def change
    create_table :achievements do |t|
      t.string :name, null: false
      t.text :description
      t.integer :points, null: false, default: 0

      t.timestamps
    end
  end
end
