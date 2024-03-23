class GameUsersTable < ActiveRecord::Migration[7.1]
  def change
    create_table :game_users do |t|
      t.json :cards, default: []
      t.belongs_to :game
      t.belongs_to :user, type: :uuid
      t.integer :view_count, default: 0
      t.string :status, default: GAME_USER_START_ACK
      t.integer :points, default: 0
      t.json :meta, default: {}
      t.timestamps
    end
  end
end
