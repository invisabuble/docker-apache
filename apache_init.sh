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


function generate_certs () {
    echo -ne "Generating SSL certificates ."

    # Generate Root CA
    openssl genpkey -algorithm RSA \
        -out "${CERT_DIR}SSL-root.key" \
        -aes256 -pass pass:$MASTER_PASSWORD \
        -pkeyopt rsa_keygen_bits:4096 -quiet
    echo -ne "."

    openssl req -x509 -new -nodes \
        -key "${CERT_DIR}SSL-root.key" \
        -sha256 -days 3650 \
        -out "${CERT_DIR}SSL-root.crt" \
        -config "${CERT_DIR}SSL-root.cnf" \
        -passin pass:$MASTER_PASSWORD > /dev/null 2>&1
    echo -ne "."

    # Array of services
    declare -A SERVICES=( ["apache"]="Apache" ["mysql"]="MySQL" ["overseer"]="Overseer" )

    for NAME in "${!SERVICES[@]}"; do
        # Generate private key for this service
        openssl genpkey -algorithm RSA \
            -out "${CERT_DIR}${NAME}.key" \
            -pkeyopt rsa_keygen_bits:4096 -quiet
        echo -ne "."

        # Generate CSR
        openssl req -new \
            -key "${CERT_DIR}${NAME}.key" \
            -out "${CERT_DIR}${NAME}.csr" \
            -config "${CERT_DIR}SSL-cert.cnf" \
            -subj "/CN=${SERVICES[$NAME]}" > /dev/null 2>&1
        echo -ne "."

        # Sign CSR with Root CA
        openssl x509 -req \
            -in "${CERT_DIR}${NAME}.csr" \
            -CA "${CERT_DIR}SSL-root.crt" \
            -CAkey "${CERT_DIR}SSL-root.key" \
            -CAcreateserial \
            -out "${CERT_DIR}${NAME}.crt" \
            -days 365 -sha256 \
            -extfile "${CERT_DIR}SSL-cert.ext" \
            -passin pass:$MASTER_PASSWORD > /dev/null 2>&1
        echo -ne "."
    done

    echo -e "\nSSL certificates generated for Apache, MySQL, and Overseer."
}



function substitute_variables () {
	# Substitute key $1 for value $2 within file $3.
	sed -i "s|$1|$2|g" "$3"
}


function populate () {
	# Copy and populate a template file with the server name and host ip.
	cp "$1" "$2"
	substitute_variables "\$SERVER_NAME" "$SERVER_NAME" "$2"
	substitute_variables "\$HOST_IP" "$HOST_IP" "$2"
	substitute_variables "\$HOSTNAME" "$HOSTNAME" "$2"
}


if [ ! -d ${CERT_DIR} ]; then
    # Create the certificate directory and copy the SSL-root.cnf to it.
    mkdir ${CERT_DIR}
    cp ${CERT_TEMPLATES}SSL-root.cnf ${CERT_DIR}SSL-root.cnf
fi

if [ ! -f ${CERT_DIR}/SSL-root.key ] || [ ! -f ${CERT_DIR}/SSL-root.crt ]; then

    # Create SSL certificate cnf, ext files from the templates.
	populate ${CERT_TEMPLATES}SSL-cert.cnf.template ${CERT_DIR}SSL-cert.cnf
	populate ${CERT_TEMPLATES}SSL-cert.ext.template ${CERT_DIR}SSL-cert.ext

    # Create the site config from the template
    populate ${WEB_CONF_DIR}site.conf.template ${WEB_CONF_DIR}site.conf

	echo -e "\033[01;91mNo SSL certificates detected.\033[0;0m"

    # Generate the .crt and .key certificates for SSL
	generate_certs

	if [ ! $? -eq 0 ]; then
		echo -e "\033[01;91mFailed to generate SSL certificates.\033[0;0m"
		exit
	fi

	echo -e "\033[01;36mEnsure you copy SSL-root.crt to your browsers CA store.\033[0;0m"

fi