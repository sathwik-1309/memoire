class LobbyTable < ActiveRecord::Migration[7.1]
  def change
    create_table :lobbies do |t|
      t.string :status, default: NEW
      t.boolean :is_filled, default: false
      t.json :players, default: []
      t.integer :game_id
      t.datetime :timeout
      t.timestamps
    end
  end
end
