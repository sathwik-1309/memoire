class GameTable < ActiveRecord::Migration[7.1]
  def change
    create_table :games do |t|
      t.string :status, null: false
      t.json :pile, default: []
      t.json :used, default: []
      t.json :inplay, default: []
      t.json :play_order, default: []
      t.string :stage, default: CARD_DRAW
      t.integer :turn
      t.integer :current_play
      t.timestamps
    end
  end
end
