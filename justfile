# Setup the `.env` file with the current architecture
init_env:
    echo "ARCH=$(uname -m)" >> .env

publish_ghcr:
    docker buildx build --platform linux/amd64,linux/arm64 -t ghcr.io/simonneutert/strava-export-organizer-web:main --push .

make:
    @echo "\n\nRun twice when in doubt ...\n\n"
    cat strava-export-organizer-bin/.tool-versions | xargs -n 2 asdf local
    asdf install
    cd strava-export-organizer-bin && go build -o ../strava-export-organizer
