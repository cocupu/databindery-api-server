# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150124110436) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "access_controls", force: true do |t|
    t.integer  "pool_id"
    t.integer  "identity_id"
    t.string   "access"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "audience_categories", force: true do |t|
    t.integer  "pool_id"
    t.string   "name"
    t.text     "description"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "audiences", force: true do |t|
    t.string   "name"
    t.text     "description"
    t.integer  "position"
    t.integer  "audience_category_id"
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

  create_table "audiences_identities", force: true do |t|
    t.integer "identity_id"
    t.integer "audience_id"
  end

  create_table "exhibits", force: true do |t|
    t.string   "title"
    t.text     "facets"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.integer  "pool_id"
    t.text     "index_fields"
  end

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

  create_table "identities", force: true do |t|
    t.string   "name"
    t.integer  "login_credential_id"
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
    t.string   "short_name"
  end

  add_index "identities", ["short_name"], name: "index_identities_on_short_name", unique: true, using: :btree

  create_table "login_credentials", force: true do |t|
    t.string   "provider",                            null: false
    t.string   "uid",                    default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email"
    t.string   "name"
    t.string   "nickname"
    t.string   "image"
    t.string   "email"
    t.text     "tokens"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "login_credentials", ["email"], name: "index_login_credentials_on_email", using: :btree
  add_index "login_credentials", ["reset_password_token"], name: "index_login_credentials_on_reset_password_token", unique: true, using: :btree
  add_index "login_credentials", ["uid", "provider"], name: "index_login_credentials_on_uid_and_provider", unique: true, using: :btree

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

  create_table "models", force: true do |t|
    t.string   "name"
    t.string   "uri"
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

  create_table "nodes", force: true do |t|
    t.text     "data"
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

  create_table "s3_connections", force: true do |t|
    t.integer  "pool_id",                                   null: false
    t.string   "access_key_id",                             null: false
    t.string   "secret_access_key",                         null: false
    t.integer  "max_file_size",     default: 10485760
    t.string   "acl",               default: "public-read"
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
  end

  create_table "search_filters", force: true do |t|
    t.string   "field_name"
    t.string   "operator"
    t.text     "values"
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.integer  "filterable_id"
    t.string   "association_code"
    t.string   "filterable_type"
    t.string   "filter_type",      default: "GRANT"
    t.integer  "field_id"
  end

  add_index "search_filters", ["filterable_id", "filterable_type"], name: "index_search_filters_on_filterable_id_and_filterable_type", using: :btree

  create_table "searches", force: true do |t|
    t.text     "query_params"
    t.integer  "login_credential_id"
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
    t.string   "user_type"
  end

  add_index "searches", ["login_credential_id"], name: "index_searches_on_login_credential_id", using: :btree

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

  add_foreign_key "exhibits", "pools", name: "exhibits_pool_id_fk"

  add_foreign_key "identities", "login_credentials", name: "identities_login_credential_id_fk"

  add_foreign_key "mapping_templates", "identities", name: "mapping_templates_identity_id_fk"
  add_foreign_key "mapping_templates", "pools", name: "mapping_templates_pool_id_fk"

  add_foreign_key "models", "identities", name: "models_identity_id_fk"
  add_foreign_key "models", "pools", name: "models_pool_id_fk"

  add_foreign_key "nodes", "identities", name: "nodes_identity_id_fk"
  add_foreign_key "nodes", "pools", name: "nodes_pool_id_fk"

  add_foreign_key "pools", "exhibits", name: "pools_chosen_default_perspective_id_fk", column: "chosen_default_perspective_id"
  add_foreign_key "pools", "identities", name: "pools_owner_id_fk", column: "owner_id"

end
