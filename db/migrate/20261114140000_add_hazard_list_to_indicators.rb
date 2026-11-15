class AddHazardListToIndicators < ActiveRecord::Migration[8.1]
  def change
    add_column :indicators, :hazard_list, :jsonb, default: [], null: false
  end
end
