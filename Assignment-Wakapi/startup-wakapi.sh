#!/bin/sh


export WAKAPI_DB_TYPE="$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/WAKAPI_DB_TYPE -H "Metadata-Flavor: Google")"
export WAKAPI_DB_NAME="$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/WAKAPI_DB_NAME -H "Metadata-Flavor: Google")"
export WAKAPI_DB_USER="$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/WAKAPI_DB_USER -H "Metadata-Flavor: Google")"
export WAKAPI_DB_HOST="$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/WAKAPI_DB_HOST -H "Metadata-Flavor: Google")"
export WAKAPI_DB_PORT="$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/WAKAPI_DB_PORT -H "Metadata-Flavor: Google")"
export WAKAPI_DB_PASSWORD="$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/WAKAPI_DB_PASSWORD -H "Metadata-Flavor: Google")"

export WAKAPI_PASSWORD_SALT="$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1)"


apt-get install -y git
mkdir -p /app
git clone "https://github.com/phuwit/KMITL-IntroCloud" /app/IntroCloud
cd /app/IntroCloud/Assignment-Wakapi

sh prepare.sh