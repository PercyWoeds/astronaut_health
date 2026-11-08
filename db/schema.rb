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

ActiveRecord::Schema[8.1].define(version: 2026_11_07_041643) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "achievements", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "points", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["mission_id"], name: "index_astronauts_on_mission_id"
  end

  create_table "body_zones", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.jsonb "related_indicators", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["astronaut_id", "indicator_type", "measured_at"], name: "idx_readings_by_astro_indicator_time"
    t.index ["astronaut_id"], name: "index_health_readings_on_astronaut_id"
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

  add_foreign_key "astronaut_achievements", "achievements"
  add_foreign_key "astronaut_achievements", "astronauts"
  add_foreign_key "astronauts", "missions"
  add_foreign_key "health_readings", "astronauts"
end
