# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  # allow do
  #   origins 'http://localhost:5173' # Replace with the origin(s) you want to allow, e.g., 'http://example.com'
  #   resource '*', headers: :any, methods: [:get, :post, :put, :patch, :delete, :options, :head], credentials: true
  # end

  # allow do
  #   origins "*" # Replace with the origin(s) you want to allow, e.g., 'http://example.com'
  #   resource '*', headers: :any, methods: [:get, :post, :put, :patch, :delete, :options, :head], credentials: false
  # end

  allow do
    origins "http://localhost:5173" # Replace with the origin(s) you want to allow, e.g., 'http://example.com'
    resource '*', headers: :any, methods: [:get, :post, :put, :patch, :delete, :options, :head], credentials: true
  end

  # allow do
  #   origins "http://localhost:4173" # Replace with the origin(s) you want to allow, e.g., 'http://example.com'
  #   resource '*', headers: :any, methods: [:get, :post, :put, :patch, :delete, :options, :head], credentials: true
  # end

  
end
