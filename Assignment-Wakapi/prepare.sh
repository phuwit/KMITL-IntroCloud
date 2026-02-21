#!/bin/sh


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

apt-get update

# install docker for real
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin


echo "$WAKAPI_DB_TYPE"
echo "$WAKAPI_DB_NAME"
echo "$WAKAPI_DB_USER"
echo "$WAKAPI_DB_HOST"
echo "$WAKAPI_DB_PORT"
echo "$WAKAPI_DB_PASSWORD"
echo "$WAKAPI_PASSWORD_SALT"

# run compose
docker compose up -d