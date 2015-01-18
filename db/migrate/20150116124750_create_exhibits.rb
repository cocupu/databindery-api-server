class CreateExhibits < ActiveRecord::Migration
  def change
    create_table "exhibits", force: true do |t|
      t.string   "title"
      t.text     "facets"
      t.datetime "created_at",   null: false
      t.datetime "updated_at",   null: false
      t.integer  "pool_id"
      t.text     "index_fields"
    end

    add_foreign_key "exhibits", "pools", :name => "exhibits_pool_id_fk"
    add_foreign_key "pools", "exhibits", :name => "pools_chosen_default_perspective_id_fk", :column => "chosen_default_perspective_id"
  end
end
