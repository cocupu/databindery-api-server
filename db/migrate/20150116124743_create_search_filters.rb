class CreateSearchFilters < ActiveRecord::Migration
  def change
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
  end
end
