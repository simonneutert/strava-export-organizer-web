# Setup the `.env` file with the current architecture

default:
    @just --list

init_env:
    echo "ARCH=$(uname -m)" >> .env

publish_ghcr:
    docker buildx build --platform linux/amd64,linux/arm64 -t ghcr.io/simonneutert/strava-export-organizer-web:main --push .

publish_ghcr_podman:
    podman manifest rm ghcr.io/simonneutert/strava-export-organizer-web:main || true
    podman manifest create ghcr.io/simonneutert/strava-export-organizer-web:main
    podman buildx build --platform linux/amd64 --manifest ghcr.io/simonneutert/strava-export-organizer-web:main .
    podman buildx build --platform linux/arm64 --manifest ghcr.io/simonneutert/strava-export-organizer-web:main .
    podman manifest push ghcr.io/simonneutert/strava-export-organizer-web:main

setup_clamav:
    @echo "🦠 Setting up ClamAV for development..."
    ruby scripts/setup_clamav.rb

dev_with_clamav:
    @echo "🐳 Starting development environment with ClamAV..."
    docker run -d --name clamav-dev -p 3310:3310 clamav/clamav:stable
    @echo "⏳ Waiting for ClamAV to be ready (this may take a few minutes)..."
    @echo "💡 You can check status with: just setup_clamav"

stop_dev_clamav:
    @echo "🛑 Stopping development ClamAV..."
    docker stop clamav-dev || true
    docker rm clamav-dev || true

prod_up:
    @echo "🚀 Starting production environment with Docker Compose..."
    docker-compose up -d

prod_down:
    @echo "🛑 Stopping production environment..."
    docker-compose down

prod_logs:
    @echo "📋 Following production logs..."
    docker-compose logs -f

update_submodules:
  git submodule update --rebase --remote

make:
    @echo "\n\nRun twice when in doubt ...\n\n"
    git submodule update --rebase --remote
    cat strava-export-organizer-bin/.tool-versions | xargs -n 2 mise local
    mise install
    cd strava-export-organizer-bin && go build -o ../strava-export-organizer
