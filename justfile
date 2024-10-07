# Setup the `.env` file with the current architecture
init_env:
    echo "ARCH=$(uname -m)" >> .env

make:
    @echo "\n\nRun twice when in doubt ...\n\n"
    cat strava-export-organizer-bin/.tool-versions | xargs -n 2 asdf local
    asdf install
    cd strava-export-organizer-bin && go build -o ../strava-export-organizer