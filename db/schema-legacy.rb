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

ActiveRecord::Schema.define(version: 20141114154642) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"



  # create_table "bookmarks", force: true do |t|
  #   t.integer  "user_id",     null: false
  #   t.string   "document_id"
  #   t.string   "title"
  #   t.datetime "created_at",  null: false
  #   t.datetime "updated_at",  null: false
  #   t.string   "user_type"
  # end

  # create_table "change_sets", force: true do |t|
  #   t.text     "data"
  #   t.integer  "pool_id"
  #   t.integer  "identity_id"
  #   t.integer  "parent_id"
  #   t.datetime "created_at",  null: false
  #   t.datetime "updated_at",  null: false
  # end

  # create_table "chattels", force: true do |t|
  #   t.string   "attachment_content_type"
  #   t.string   "attachment_file_name"
  #   t.string   "attachment_extension"
  #   t.datetime "created_at",              null: false
  #   t.datetime "updated_at",              null: false
  #   t.integer  "owner_id"
  # end




  create_table "google_accounts", force: true do |t|
    t.integer  "owner_id"
    t.string   "profile_id"
    t.string   "email"
    t.string   "refresh_token"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end
  add_foreign_key "google_accounts", "identities", :name => "google_accounts_owner_id_fk", :column => "owner_id"






  # create_table "searches", force: true do |t|
  #   t.text     "query_params"
  #   t.integer  "user_id"
  #   t.datetime "created_at",   null: false
  #   t.datetime "updated_at",   null: false
  #   t.string   "user_type"
  # end
  #
  # add_index "searches", ["user_id"], name: "index_searches_on_user_id", using: :btree

  # create_table "sessions", force: true do |t|
  #   t.string   "session_id", null: false
  #   t.text     "data"
  #   t.datetime "created_at", null: false
  #   t.datetime "updated_at", null: false
  # end
  #
  # add_index "sessions", ["session_id"], name: "index_sessions_on_session_id", using: :btree
  # add_index "sessions", ["updated_at"], name: "index_sessions_on_updated_at", using: :btree





  # add_foreign_key "change_sets", "change_sets", :name => "change_sets_parent_id_fk", :column => "parent_id"
  # add_foreign_key "change_sets", "identities", :name => "change_sets_identity_id_fk"
  # add_foreign_key "change_sets", "pools", :name => "change_sets_pool_id_fk"

  # add_foreign_key "chattels", "identities", :name => "chattels_owner_id_fk", :column => "owner_id"




end
