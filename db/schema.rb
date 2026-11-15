# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_14_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "achievements", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "points", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "alerts", force: :cascade do |t|
    t.bigint "astronaut_id", null: false
    t.bigint "indicator_id", null: false
    t.string "level", null: false
    t.string "basis", null: false
    t.string "status", default: "open", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["astronaut_id", "status"], name: "index_alerts_on_astronaut_id_and_status"
    t.index ["astronaut_id"], name: "index_alerts_on_astronaut_id"
    t.index ["indicator_id"], name: "index_alerts_on_indicator_id"
  end

  create_table "astronaut_achievements", force: :cascade do |t|
    t.bigint "astronaut_id", null: false
    t.bigint "achievement_id", null: false
    t.datetime "awarded_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["achievement_id"], name: "index_astronaut_achievements_on_achievement_id"
    t.index ["astronaut_id", "achievement_id"], name: "idx_on_astronaut_id_achievement_id_d6a385e5c8", unique: true
    t.index ["astronaut_id"], name: "index_astronaut_achievements_on_astronaut_id"
  end

  create_table "astronauts", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "mission_id", null: false
    t.string "destination", default: "iss", null: false
    t.index ["mission_id"], name: "index_astronauts_on_mission_id"
  end

  create_table "baselines", force: :cascade do |t|
    t.bigint "astronaut_id", null: false
    t.bigint "indicator_id", null: false
    t.float "mean", null: false
    t.float "std", null: false
    t.integer "samples", default: 0, null: false
    t.string "source", default: "pre-flight", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["astronaut_id", "indicator_id"], name: "index_baselines_on_astronaut_id_and_indicator_id", unique: true
    t.index ["astronaut_id"], name: "index_baselines_on_astronaut_id"
    t.index ["indicator_id"], name: "index_baselines_on_indicator_id"
  end

  create_table "biomarker_samples", force: :cascade do |t|
    t.bigint "astronaut_id", null: false
    t.string "sample_type", null: false
    t.datetime "collected_at", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["astronaut_id", "collected_at"], name: "index_biomarker_samples_on_astronaut_id_and_collected_at"
    t.index ["astronaut_id"], name: "index_biomarker_samples_on_astronaut_id"
  end

  create_table "body_zones", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.jsonb "related_indicators", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "daily_checks", force: :cascade do |t|
    t.bigint "astronaut_id", null: false
    t.date "checked_on", null: false
    t.float "bone_density_loss_percent", default: 0.0, null: false
    t.integer "co2_level", default: 0, null: false
    t.integer "stress_level", default: 1, null: false
    t.integer "calories_intake", default: 0, null: false
    t.boolean "vision_blurred", default: false, null: false
    t.boolean "dizziness_reported", default: false, null: false
    t.boolean "skin_rash", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["astronaut_id", "checked_on"], name: "index_daily_checks_on_astronaut_id_and_checked_on", unique: true
    t.index ["astronaut_id"], name: "index_daily_checks_on_astronaut_id"
  end

  create_table "ground_reports", force: :cascade do |t|
    t.bigint "alert_id", null: false
    t.text "summary", null: false
    t.date "sent_day", null: false
    t.string "status", default: "sent", null: false
    t.datetime "earliest_reply_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_id"], name: "index_ground_reports_on_alert_id"
    t.index ["sent_day"], name: "index_ground_reports_on_sent_day"
  end

  create_table "health_readings", force: :cascade do |t|
    t.bigint "astronaut_id", null: false
    t.string "indicator_type", null: false
    t.float "value", null: false
    t.string "unit", null: false
    t.datetime "measured_at", null: false
    t.string "status", default: "green", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_baseline", default: false, null: false
    t.integer "reaction_time_ms"
    t.integer "meals_completed_percent"
    t.integer "social_contact_minutes"
    t.boolean "confirmed", default: false, null: false
    t.index ["astronaut_id", "indicator_type", "is_baseline"], name: "idx_readings_baseline_lookup"
    t.index ["astronaut_id", "indicator_type", "measured_at"], name: "idx_readings_by_astro_indicator_time"
    t.index ["astronaut_id"], name: "index_health_readings_on_astronaut_id"
  end

  create_table "indicators", force: :cascade do |t|
    t.string "key", null: false
    t.string "axis", null: false
    t.string "unit", null: false
    t.string "bad_direction", null: false
    t.float "abs_min"
    t.float "abs_max"
    t.float "yellow_min"
    t.float "yellow_max"
    t.float "red_min"
    t.float "red_max"
    t.text "hazards"
    t.string "source_url"
    t.integer "frequency_days", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_indicators_on_key", unique: true
  end

  create_table "journal_entries", force: :cascade do |t|
    t.bigint "astronaut_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["astronaut_id"], name: "index_journal_entries_on_astronaut_id"
  end

  create_table "missions", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.text "description"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_missions_on_code", unique: true
  end

  create_table "pre_eva_checks", force: :cascade do |t|
    t.bigint "astronaut_id", null: false
    t.boolean "o2_ok", default: false, null: false
    t.boolean "pressure_ok", default: false, null: false
    t.boolean "fatigue_ok", default: false, null: false
    t.datetime "checked_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "egress_fitness_completed", default: false, null: false
    t.index ["astronaut_id"], name: "index_pre_eva_checks_on_astronaut_id"
  end

  create_table "research_assessments", force: :cascade do |t|
    t.bigint "astronaut_id", null: false
    t.date "assessed_on", null: false
    t.boolean "saliva_sample_taken", default: false, null: false
    t.boolean "virus_reactivation_suspected", default: false, null: false
    t.float "calcium_isotopes_level"
    t.float "telomere_length"
    t.integer "spatial_cognition_score"
    t.boolean "vestibular_test_passed", default: false, null: false
    t.boolean "vision_test_performed", default: false, null: false
    t.string "oct_scan_result", default: "normal", null: false
    t.boolean "b_complex_supplement_taken", default: false, null: false
    t.boolean "actigraphy_device_synced", default: false, null: false
    t.integer "cognitive_performance_survey_score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["astronaut_id", "assessed_on"], name: "index_research_assessments_on_astronaut_id_and_assessed_on", unique: true
    t.index ["astronaut_id"], name: "index_research_assessments_on_astronaut_id"
  end

  create_table "symptom_checks", force: :cascade do |t|
    t.bigint "astronaut_id", null: false
    t.date "checked_on", null: false
    t.boolean "rash_or_hives", default: false, null: false
    t.boolean "vision_changes", default: false, null: false
    t.boolean "dizziness_nausea", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["astronaut_id", "checked_on"], name: "index_symptom_checks_on_astronaut_id_and_checked_on", unique: true
    t.index ["astronaut_id"], name: "index_symptom_checks_on_astronaut_id"
  end

  create_table "symptom_reports", force: :cascade do |t|
    t.bigint "astronaut_id", null: false
    t.boolean "rash", default: false, null: false
    t.boolean "vision_change", default: false, null: false
    t.boolean "dizziness", default: false, null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["astronaut_id"], name: "index_symptom_reports_on_astronaut_id"
  end

  add_foreign_key "alerts", "astronauts"
  add_foreign_key "alerts", "indicators"
  add_foreign_key "astronaut_achievements", "achievements"
  add_foreign_key "astronaut_achievements", "astronauts"
  add_foreign_key "astronauts", "missions"
  add_foreign_key "baselines", "astronauts"
  add_foreign_key "baselines", "indicators"
  add_foreign_key "biomarker_samples", "astronauts"
  add_foreign_key "daily_checks", "astronauts"
  add_foreign_key "ground_reports", "alerts"
  add_foreign_key "health_readings", "astronauts"
  add_foreign_key "journal_entries", "astronauts"
  add_foreign_key "pre_eva_checks", "astronauts"
  add_foreign_key "research_assessments", "astronauts"
  add_foreign_key "symptom_checks", "astronauts"
  add_foreign_key "symptom_reports", "astronauts"
end
