class AddTypeToPools < ActiveRecord::Migration
  def change
    # Add 'type' column and mark existing pools as 'SqlBackedPool'
    add_column :pools, :type, :string, default: 'SqlBackedPool'
  end
end
