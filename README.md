# Strava Export Organizer Web App

This is a web app that accepts a Strava export (zip file) and returns a zip file with the activities organized by type and year.

See the [Strava Export Organizer](https://github.com/simonneutert/strava-export-organizer) main repo for more details.

**Please** check the currently supported languages of strava exports [here](https://github.com/simonneutert/strava-export-organizer), sadly they aren't uniform!

☝️ Help me add more languages, by providing the first few lines of your export's `activities.csv`.

### Security 😅

- Downloadable zip files have a shelf life of 5 minutes.
- Downloadable zip file's filename contain a random 20 sign long string.
- Run locally to be 100 % secure (using Docker). Read on for instructions.

## Technical Nutshell

This repo uses [Strava Export Organizer](https://github.com/simonneutert/strava-export-organizer) as a submodule. Make sure to clone with submodules. And update the submodule to the latest version (regularly).

## Hosted version

https://strava-export-organizer.trojanischeresel.de

### But ... ⭐️ why not run this project locally (with [Docker](https://www.docker.com))?

The server that hosts the app is a silicon potato. But the much greater benefits of using docker: nothing is sent over the wire and it will feel super duper fast.

Much faster, no internet connection required (once you have downloaded the image). So much wow.

```bash
docker run --rm -p 3000:3000 ghcr.io/simonneutert/strava-export-organizer-web:main
```

Then visit http://localhost:3000 in your browser of choice (it should be Firefox and you know this deep in your heart).

## Planned Features

- [ ] Throttle requests

## Developer Docs

[Developer Docs](DEVELOPMENT.md)