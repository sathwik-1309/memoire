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

ActiveRecord::Schema[7.1].define(version: 2024_03_06_180728) do
  create_table "game_users", force: :cascade do |t|
    t.json "cards", default: []
    t.integer "game_id"
    t.integer "user_id"
    t.integer "view_count", default: 0
    t.string "status", default: "start_ack"
    t.integer "points", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id"], name: "index_game_users_on_game_id"
    t.index ["user_id"], name: "index_game_users_on_user_id"
  end

  create_table "games", force: :cascade do |t|
    t.string "status", default: "new"
    t.json "pile", default: []
    t.json "used", default: []
    t.json "inplay", default: []
    t.json "play_order", default: []
    t.string "stage", default: "start_ack"
    t.integer "turn"
    t.integer "current_play"
    t.datetime "timeout"
    t.json "meta", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "plays", force: :cascade do |t|
    t.integer "turn"
    t.boolean "show", default: false
    t.json "card_draw", default: {}
    t.json "offloads", default: []
    t.json "powerplay", default: {}
    t.integer "game_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id"], name: "index_plays_on_game_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "authentication_token"
    t.string "username", null: false
    t.string "password"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
