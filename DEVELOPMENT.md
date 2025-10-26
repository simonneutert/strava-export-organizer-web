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
# Optional: Set up ClamAV for testing virus scanning
just dev_with_clamav
just setup_clamav  # Test ClamAV setup
bundle exec rackup
```

## Dockered Development

```bash
# Basic development
docker build -t strava-export-organizer-web-app .
docker run -p 3000:3000 strava-export-organizer-web-app

# Development with ClamAV (recommended)
docker-compose up -d
```

## ClamAV Integration

The application includes optional ClamAV virus scanning:

**Important:** ClamAV is accessed exclusively via TCP port 3310. The application uses the INSTREAM command to send file contents over the network connection, as ClamAV runs in Docker/Podman without direct file system access.

### Development Setup

```bash
# Start ClamAV daemon for development
just dev_with_clamav

# Test ClamAV setup
just setup_clamav

# Stop development ClamAV
just stop_dev_clamav
```

### Production Setup

```bash
# Start production environment (includes ClamAV)
just prod_up

# View logs
just prod_logs

# Stop production environment
just prod_down
```

### Environment Variables

- `CLAMAV_ENABLED=true` - Enable virus scanning
- `CLAMAV_HOST=localhost` - ClamAV daemon host
- `CLAMAV_PORT=3310` - ClamAV daemon port

## Release a package to GHCR.io

```bash
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -t ghcr.io/simonneutert/strava-export-organizer-web:latest \
    --push .
```
