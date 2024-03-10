class GameUsersTable < ActiveRecord::Migration[7.1]
  def change
    create_table :game_users do |t|
      t.json :cards, default: []
      t.belongs_to :game
      t.belongs_to :user
      t.integer :view_count, default: 0
      t.boolean :start_ack, default: false
      t.timestamps
    end
  end
end
