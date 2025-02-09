## Warning ⚠️ <!-- omit from toc -->

This project is intentionally overly complicated.

The reason being two things I wanted to learn and bring to use:

* Git submodules
* Using a Go executable for a part of the business logic (it does it all in this case 😅)

---

- [Local Development](#local-development)
- [Dockered Development](#dockered-development)
- [Release a package to GHCR.io](#release-a-package-to-ghcrio)


## Local Development

Your OS needs to provide `find` ✌️ (the one you use with Docker,too)

### clone with submodules<!-- omit from toc -->

```bash
git clone <this-repo> --recurse-submodules
```

### Dependencies<!-- omit from toc -->

```bash
asdf install
just make
bundle install
bundle exec rackup
```

## Dockered Development

```bash
docker build -t strava-export-organizer-web-app .
docker run -p 3000:3000 strava-export-organizer-web-app
```

## Release a package to GHCR.io

```bash
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -t ghcr.io/simonneutert/strava-export-organizer-web:latest \
    --push .
```
