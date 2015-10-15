class AddDatLocationToPools < ActiveRecord::Migration
  def change
    add_column :pools, :dat_location, :string
  end
end
