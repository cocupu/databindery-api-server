class CreateNodesModelsAndFields < ActiveRecord::Migration
  def change
    create_table "models", force: true do |t|
      t.string   "name"
      # t.text     "fields"
      # t.text     "associations"
      t.datetime "created_at",                         null: false
      t.datetime "updated_at",                         null: false
      t.string   "label"
      t.integer  "identity_id"
      t.integer  "pool_id"
      t.string   "code"
      t.boolean  "allow_file_bindings", default: true
      t.integer  "label_field_id"
    end

    add_index "models", ["code"], name: "index_models_on_code", unique: true, using: :btree
    add_index "models", ["identity_id"], name: "index_models_on_identity_id", using: :btree
    add_foreign_key "models", "pools", :name => "models_pool_id_fk"

    create_table "nodes", force: true do |t|
      t.text     "data"
      # t.text     "associations"
      t.string   "persistent_id"
      t.string   "parent_id"
      t.integer  "pool_id"
      t.integer  "identity_id"
      t.datetime "created_at",                            null: false
      t.datetime "updated_at",                            null: false
      t.integer  "model_id"
      t.string   "binding"
      t.integer  "spawned_from_node_id"
      t.integer  "spawned_from_datum_id"
      t.integer  "modified_by_id"
      t.boolean  "is_fork",               default: false
      t.string   "log"
    end

    add_index "nodes", ["binding"], name: "index_nodes_on_binding", using: :btree
    add_index "nodes", ["model_id"], name: "index_nodes_on_model_id", using: :btree
    add_foreign_key "nodes", "pools", :name => "nodes_pool_id_fk"

    create_table "fields", force: true do |t|
      t.string   "name"
      t.string   "type"
      t.string   "uri"
      t.string   "code"
      t.string   "label"
      t.boolean  "multivalue"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "references"
    end

    create_table "fields_models", id: false, force: true do |t|
      t.integer "field_id"
      t.integer "model_id"
    end
  end
end
