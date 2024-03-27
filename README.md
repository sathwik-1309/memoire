## Commands

### initial bots create
`rails r lib/scripts/create_bots.rb`

### run postgres in docker
`docker run --name postgres-container \
-e POSTGRES_DB=myapi \
-e POSTGRES_USER=root \
-e POSTGRES_PASSWORD=password \
-d \
-p 5432:5432 \
postgres:latest`

### run redis in docker
`docker run --name my-redis-container -d -p 6379:6379 redis`