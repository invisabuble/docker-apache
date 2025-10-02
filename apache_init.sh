#!/bin/bash
set -euo pipefail

# Always work from the directory of this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Setup the SSL certificates for the apache webserver allowing the user to connect via https.
# Add the host ip to the apache.env file.
grep -q "^HOST_IP=" apache.env || echo -e "\nHOST_IP=$(hostname -I | awk '{print $1}')" >> apache.env

source apache.env

# If no URL is set then set the SERVER_NAME to the HOST_IP otherwise set it to the URL.
[ "$URL" == "" ] && SERVER_NAME=$HOST_IP || SERVER_NAME=$URL

mkdir ${CERT_DIR}

./create_certs.sh "overseer" "Overseer"
./create_certs.sh "apache" "Overseer_FE"
./create_certs.sh "mysql" "Overseer_DB"