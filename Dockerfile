FROM golang:1.24-alpine AS builder

WORKDIR /app
COPY strava-export-organizer-bin/ .
RUN go build -o strava-export-organizer

FROM phusion/passenger-ruby34

RUN apt-get update && apt-get install -y \
  unzip \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /app

COPY Gemfile Gemfile.lock /app/
RUN bundle install

COPY app.rb config.ru /app/
COPY assets/ /app/assets/
COPY config/ /app/config/
COPY lib/ /app/lib/
COPY i18n/ /app/i18n/
RUN mkdir -p /app/public/assets
COPY views/ /app/views/

COPY --from=builder /app/strava-export-organizer /app/strava-export-organizer
RUN mkdir -p tmp/stravaexport_done

EXPOSE 3000

RUN useradd -m appuser && chown -R appuser:appuser /app

ENV RACK_ENV=production
CMD ["/sbin/setuser", "appuser", "bundle", "exec", "passenger", "start"]
