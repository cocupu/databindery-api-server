class CreateIdentities < ActiveRecord::Migration
  def change
    create_table "identities", force: true do |t|
      t.string   "name"
      t.integer  "login_credential_id"
      t.datetime "created_at",          null: false
      t.datetime "updated_at",          null: false
      t.string   "short_name"
    end

    add_index "identities", ["short_name"], name: "index_identities_on_short_name", unique: true, using: :btree
    add_foreign_key "identities", "login_credentials", :name => "identities_login_credential_id_fk"
    add_foreign_key "pools", "identities", :name => "pools_owner_id_fk", :column => "owner_id"
    add_foreign_key "models", "identities", :name => "models_identity_id_fk"
    add_foreign_key "nodes", "identities", :name => "nodes_identity_id_fk"
  end
end
