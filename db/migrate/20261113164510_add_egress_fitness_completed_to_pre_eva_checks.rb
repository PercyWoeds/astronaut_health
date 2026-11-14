class AddEgressFitnessCompletedToPreEvaChecks < ActiveRecord::Migration[8.1]
  def change
    add_column :pre_eva_checks, :egress_fitness_completed, :boolean, null: false, default: false
  end
end
