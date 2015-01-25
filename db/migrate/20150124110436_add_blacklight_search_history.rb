class AddBlacklightSearchHistory < ActiveRecord::Migration
  def change
    create_table "searches", force: true do |t|
      t.text     "query_params"
      t.integer  "login_credential_id"
      t.datetime "created_at",   null: false
      t.datetime "updated_at",   null: false
      t.string   "user_type"
    end

    add_index "searches", ["login_credential_id"], name: "index_searches_on_login_credential_id", using: :btree
  end
end
