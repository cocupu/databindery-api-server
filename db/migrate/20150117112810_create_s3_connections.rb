class CreateS3Connections < ActiveRecord::Migration
  def change
    create_table "s3_connections", force: true do |t|
      t.integer  "pool_id",                                   null: false
      t.string   "access_key_id",                             null: false
      t.string   "secret_access_key",                         null: false
      t.integer  "max_file_size",     default: 10485760
      t.string   "acl",               default: "public-read"
      t.datetime "created_at",                                null: false
      t.datetime "updated_at",                                null: false
    end
  end
end
