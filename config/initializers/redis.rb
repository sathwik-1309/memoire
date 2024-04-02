require 'redis'

$redis = Redis.new(url: ENV['REDIS_URL_CACHE'] || 'redis://localhost:6379/2')