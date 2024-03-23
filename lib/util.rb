require 'securerandom'

module Util
  def self.generate_random_string(length)
    SecureRandom.alphanumeric(length)
  end

  def self.get_card_value(card)
    return card.split(" ")
  end

  def self.get_card_number(card)
    return card.split(" ")[0]
  end

  def self.pick_n_random_items(array, n)
    array.shuffle.take(n)
  end

  def self.card_memory_init
    hash = {}
    VALUES.each do |val|
      hash[val] = []
    end
    hash
  end

  def self.seen_card_memory(card, index)
    {
      'seen' => true,
      'value' => card,
      'index' => index
    }
  end
  
end