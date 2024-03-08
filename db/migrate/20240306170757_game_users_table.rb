class GameUsersTable < ActiveRecord::Migration[7.1]
  def change
    create_table :game_users do |t|
      t.json :cards, default: []
      t.belongs_to :game
      t.belongs_to :user
      t.boolean :initial_view, default: false
      t.timestamps
    end
  end
end
