class CreatePools < ActiveRecord::Migration
  def change
    create_table "pools", force: true do |t|
      t.string   "name"
      t.integer  "owner_id"
      t.datetime "created_at",                    null: false
      t.datetime "updated_at",                    null: false
      t.integer  "head_id"
      t.string   "short_name"
      t.text     "description"
      t.integer  "chosen_default_perspective_id"
      t.string   "persistent_id"
    end

    add_index "pools", ["short_name"], name: "index_pools_on_short_name", unique: true, using: :btree
  end
end
