# config/initializers/sidekiq.rb

Sidekiq.configure_server do |config|
  config.redis = { url: 'redis://localhost:6379/0' }
end

Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://localhost:6379/0' }
end

# Load custom configuration from sidekiq.yml if present
# sidekiq_config_file = Rails.root.join('config', 'sidekiq.yml')
# if File.exist?(sidekiq_config_file)
#   Sidekiq.options.merge!(YAML.load_file(sidekiq_config_file).deep_symbolize_keys)
# end
