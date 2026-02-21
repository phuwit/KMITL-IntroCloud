#!/bin/sh


APP_DIRECTORY="/app/wakapi"


mkdir -p "$APP_DIRECTORY"

# update and upgrade
apt-get update
# apt-get upgrade -y

# install docker
# Add Docker's official GPG key:
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# install docker for real
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# create a compose
tee "$APP_DIRECTORY/compose.yml" <<EOF
services:
  wakapi:
    image: ghcr.io/muety/wakapi:latest
    ports:
      - 3000:3000
    restart: unless-stopped
    volumes:
      - ./wakapi-data:/data
EOF

# write variables to a file (it wouldnt wouldnt with export for some reason)
tee "$APP_DIRECTORY/.env" <<EOF
WAKAPI_DB_TYPE="$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/WAKAPI_DB_TYPE -H "Metadata-Flavor: Google")"
WAKAPI_DB_NAME="$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/WAKAPI_DB_NAME -H "Metadata-Flavor: Google")"
WAKAPI_DB_USER="$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/WAKAPI_DB_USER -H "Metadata-Flavor: Google")"
WAKAPI_DB_HOST="$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/WAKAPI_DB_HOST -H "Metadata-Flavor: Google")"
WAKAPI_DB_PORT="$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/WAKAPI_DB_PORT -H "Metadata-Flavor: Google")"
WAKAPI_DB_PASSWORD="$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/WAKAPI_DB_PASSWORD -H "Metadata-Flavor: Google")"
WAKAPI_PASSWORD_SALT="$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1)"
EOF

# run compose
docker compose up -d