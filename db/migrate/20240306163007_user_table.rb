class UserTable < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :authentication_token
      t.string :username, null: false
      t.string :password
      t.boolean :is_bot, default: :false
      t.timestamps
    end
  end
end
