# Use the official Ruby image with tag for Ruby 3.0
FROM ruby:3.2-alpine

# Set the working directory in the container
WORKDIR /rails-api

# Install dependencies
RUN apk add --update --no-cache \
    build-base \
    postgresql-dev \
    tzdata \
    nodejs \
    yarn

# Copy the Gemfile and Gemfile.lock into the image.
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle install

# Copy the rest of the application code into the image.
COPY . .

# Expose port 3000 to the Docker host, so it can be accessed from the outside.
EXPOSE 3000
#
#CMD [ "rails" ,"s","-b","0.0.0.0"]
