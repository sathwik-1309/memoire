class UserTable < ActiveRecord::Migration[7.1]
  def change
    create_table :users, id: :uuid do |t|
      t.string :name, null: false
      t.string :authentication_token
      t.string :username, null: false
      t.string :password
      t.timestamps
    end
  end
end
