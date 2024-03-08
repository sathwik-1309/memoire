class PlayTable < ActiveRecord::Migration[7.1]
  def change
    create_table :plays do |t|
      t.integer :turn
      t.boolean :show, default: false
      t.json :card_draw, default: {}
      t.json :offloads, default: []
      t.json :powerplay, default: {}

      t.belongs_to :game
      t.timestamps
    end
  end
end
