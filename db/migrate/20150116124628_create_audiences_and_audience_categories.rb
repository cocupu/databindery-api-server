class CreateAudiencesAndAudienceCategories < ActiveRecord::Migration
  def change
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
  end
end
