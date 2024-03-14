require 'securerandom'

module Util
  def self.generate_random_string(length)
    SecureRandom.alphanumeric(length)
  end

  def self.get_card_value(card)
    return card.split(" ")
  end

  def pick_n_random_items(array, n)
    array.shuffle.take(n)
  end
  
end