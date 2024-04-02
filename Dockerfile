FROM ruby:2.7.8-alpine as base

RUN apk update && \
    apk add bash
#    postgresql-dev

RUN apk add --no-cache tzdata
ENV TZ=UTC

# Set working directory
WORKDIR backend

FROM base as gem-cache

# Copy the application
COPY Gemfile /backend
COPY Gemfile.lock /backend

# General utilities
RUN apk add --no-cache build-base git && \
    gem install bundler -v 2.3.5 && \
     bundle install

FROM base

ARG REDIS_URL

ENV REDIS_URL $REDIS_URL

COPY --from=gem-cache /usr/local/bundle /usr/local/bundle
COPY . /backend

EXPOSE 3000
# Set the entrypoint
# ENTRYPOINT ["puma", "-C", "config/puma.rb"]