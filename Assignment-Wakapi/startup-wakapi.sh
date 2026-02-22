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
      - 80:3000
    restart: unless-stopped
    volumes:
      - ./wakapi-data:/data
    secrets:
      - source: password_salt
        target: password_salt
        uid: '1000'
        gid: '1000'
        mode: '0400'

      - source: db_password
        target: db_password
        uid: '1000'
        gid: '1000'
        mode: '0400'
    environment:
      - WAKAPI_DB_TYPE
      - WAKAPI_DB_NAME
      - WAKAPI_DB_USER
      - WAKAPI_DB_HOST
      - WAKAPI_DB_PORT
      - WAKAPI_DB_PASSWORD
      - WAKAPI_PASSWORD_SALT

secrets:
  password_salt:
    environment: WAKAPI_PASSWORD_SALT
  smtp_pass:
    environment: WAKAPI_MAIL_SMTP_PASS
  db_password:
    environment: WAKAPI_DB_PASSWORD
EOF

# export variables
export WAKAPI_DB_TYPE=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/WAKAPI_DB_TYPE -H "Metadata-Flavor: Google")
export WAKAPI_DB_NAME=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/WAKAPI_DB_NAME -H "Metadata-Flavor: Google")
export WAKAPI_DB_USER=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/WAKAPI_DB_USER -H "Metadata-Flavor: Google")
export WAKAPI_DB_HOST=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/WAKAPI_DB_HOST -H "Metadata-Flavor: Google")
export WAKAPI_DB_PORT=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/WAKAPI_DB_PORT -H "Metadata-Flavor: Google")
export WAKAPI_DB_PASSWORD="$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/WAKAPI_DB_PASSWORD -H "Metadata-Flavor: Google")"
export WAKAPI_PASSWORD_SALT="$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1)"

# run compose
docker compose --file "$APP_DIRECTORY/compose.yml" up --detach