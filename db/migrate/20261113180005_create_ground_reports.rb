class CreateGroundReports < ActiveRecord::Migration[8.1]
  def change
    create_table :ground_reports do |t|
      t.references :alert, null: false, foreign_key: true
      t.text :summary, null: false
      t.date :sent_day, null: false
      t.string :status, null: false, default: "sent"
      t.datetime :earliest_reply_at

      t.timestamps
    end

    add_index :ground_reports, :sent_day
  end
end
