FROM golang:1 AS builder

WORKDIR /app

COPY strava-export-organizer-bin/ .

RUN go build -o strava-export-organizer

FROM phusion/passenger-ruby33

RUN apt-get update && apt-get install -y \
  unzip
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /app

COPY Gemfile /app/
COPY Gemfile.lock /app/
RUN bundle install

RUN mkdir -p tmp/stravaexport_done

ADD . .
RUN rm -rf strava-export-organizer-bin
COPY --from=builder /app/strava-export-organizer /app/strava-export-organizer

EXPOSE 3000
CMD ["bundle", "exec", "passenger", "start"]