class GameTable < ActiveRecord::Migration[7.1]
  def change
    create_table :games do |t|
      t.string :status, default: NEW
      t.json :pile, default: []
      t.json :used, default: []
      t.json :inplay, default: []
      t.json :play_order, default: []
      t.string :stage, default: START_ACK
      t.integer :turn
      t.integer :current_play
      t.datetime :timeout
      t.integer :counter, default: 1
      t.json :meta, default: {}
      t.timestamps
    end
  end
end
