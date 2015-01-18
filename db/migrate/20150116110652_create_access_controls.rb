class CreateAccessControls < ActiveRecord::Migration
  def change
    create_table "access_controls", force: true do |t|
      t.integer  "pool_id"
      t.integer  "identity_id"
      t.string   "access"
      t.datetime "created_at",  null: false
      t.datetime "updated_at",  null: false
    end
  end
end
