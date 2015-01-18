class AddSpawning < ActiveRecord::Migration
  def change
    create_table "spawn_jobs", force: true do |t|
      t.text     "reification_job_ids"
      t.integer  "mapping_template_id"
      t.integer  "node_id"
      t.integer  "pool_id"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "spawn_jobs", ["mapping_template_id"], name: "index_spawn_jobs_on_mapping_template_id", using: :btree
    add_index "spawn_jobs", ["node_id"], name: "index_spawn_jobs_on_node_id", using: :btree
    add_index "spawn_jobs", ["pool_id"], name: "index_spawn_jobs_on_pool_id", using: :btree

    create_table "mapping_templates", force: true do |t|
      t.integer  "row_start"
      t.text     "model_mappings"
      t.datetime "created_at",     null: false
      t.datetime "updated_at",     null: false
      t.string   "file_type"
      t.integer  "identity_id"
      t.integer  "pool_id"
    end

    add_index "mapping_templates", ["identity_id"], name: "index_mapping_templates_on_identity_id", using: :btree

    add_foreign_key "mapping_templates", "identities", :name => "mapping_templates_identity_id_fk"
    add_foreign_key "mapping_templates", "pools", :name => "mapping_templates_pool_id_fk"
  end
end
