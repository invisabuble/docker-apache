source apache.env

# If no URL is set then set the SERVER_NAME to the HOST_IP otherwise set it to the URL.
[ "$URL" == "" ] && SERVER_NAME=$HOST_IP || SERVER_NAME=$URL

function substitute_variables () {
	# Substitute key $1 for value $2 within file $3.
	sed -i "s|$1|$2|g" "$3"
}


function populate () {
	# Copy and populate a template file with the server name and host ip.
	cp "$1" "$2"
	substitute_variables "\$SERVER_NAME" "$3" "$2"
	substitute_variables "\$HOST_IP" "$HOST_IP" "$2"
	substitute_variables "\$HOSTNAME" "$HOSTNAME" "$2"
}


function generate_root_ca () {
    # Generate a root CA.

    echo -ne "Generating root CA ."
    mkdir ${CERT_DIR}root

    # Create SSL certificate cnf, ext files from the templates.
	populate ${CERT_TEMPLATES}SSL-cert.cnf.template ${CERT_DIR}root/SSL-root.cnf $SERVER_NAME
	populate ${CERT_TEMPLATES}SSL-cert.ext.template ${CERT_DIR}root/SSL-root.ext $SERVER_NAME
    cp ${CERT_TEMPLATES}SSL-client.ext ${CERT_DIR}root/SSL-client.ext

    openssl genpkey -algorithm RSA \
        -out "${CERT_DIR}root/SSL-root.key" \
        -aes256 -pass pass:$MASTER_PASSWORD \
        -pkeyopt rsa_keygen_bits:4096 -quiet
    echo -ne "."

    openssl req -x509 -new -nodes \
        -key "${CERT_DIR}root/SSL-root.key" \
        -sha256 -days 3650 \
        -out "${CERT_DIR}root/SSL-root.crt" \
        -config "${CERT_DIR}root/SSL-root.cnf" \
        -passin pass:$MASTER_PASSWORD > /dev/null 2>&1
    echo -e "."

    # Set the certificate permissions.
    chmod 644 ${CERT_DIR}root/SSL-root.crt
    chmod 600 ${CERT_DIR}root/SSL-root.key

}


function generate_service_cert () {
    # Generate server and client certificates for a given service

    echo -ne "Generating server certificate for ${1} ."

    # Create a directory per service for holding all certs.
    mkdir ${CERT_DIR}${1}

    # Create SSL certificate cnf, ext files for mysql.
    populate ${CERT_TEMPLATES}SSL-cert.cnf.template ${CERT_DIR}${1}/SSL-${1}.cnf $2
	populate ${CERT_TEMPLATES}SSL-cert.ext.template ${CERT_DIR}${1}/SSL-${1}.ext $2

    # Server private key
    openssl genpkey -algorithm RSA \
        -out "${CERT_DIR}${1}/${1}-server.key" \
        -pkeyopt rsa_keygen_bits:4096 -quiet
    echo -ne "."

    # Server CSR
    openssl req -new \
        -key "${CERT_DIR}${1}/${1}-server.key" \
        -out "${CERT_DIR}${1}/${1}-server.csr" \
        -config "${CERT_DIR}${1}/SSL-${1}.cnf" \
        -subj "/CN=${1} Server" > /dev/null 2>&1
    echo -ne "."

    # Server signed certificate
    openssl x509 -req \
        -in "${CERT_DIR}${1}/${1}-server.csr" \
        -CA "${CERT_DIR}root/SSL-root.crt" \
        -CAkey "${CERT_DIR}root/SSL-root.key" \
        -CAcreateserial \
        -out "${CERT_DIR}${1}/${1}-server.crt" \
        -days 365 -sha256 \
        -extfile "${CERT_DIR}${1}/SSL-${1}.ext" \
        -passin pass:$MASTER_PASSWORD > /dev/null 2>&1
    echo -ne "."

    # Set the server certificate permissions.
    chmod 644 ${CERT_DIR}${1}/${1}-server.crt
    chmod 600 ${CERT_DIR}${1}/${1}-server.key

    # ----- Client certificate -----
    echo -ne "\nGenerating client certificate for ${1} ."

    # Client private key
    openssl genpkey -algorithm RSA \
        -out "${CERT_DIR}${1}/${1}-client.key" \
        -pkeyopt rsa_keygen_bits:4096 -quiet
    echo -ne "."

    # Client CSR
    openssl req -new \
        -key "${CERT_DIR}${1}/${1}-client.key" \
        -out "${CERT_DIR}${1}/${1}-client.csr" \
        -config "${CERT_DIR}${1}/SSL-${1}.cnf" \
        -subj "/CN=${1} Client" > /dev/null 2>&1
    echo -ne "."

    # Client signed certificate
    openssl x509 -req \
        -in "${CERT_DIR}${1}/${1}-client.csr" \
        -CA "${CERT_DIR}root/SSL-root.crt" \
        -CAkey "${CERT_DIR}root/SSL-root.key" \
        -CAcreateserial \
        -out "${CERT_DIR}${1}/${1}-client.crt" \
        -days 365 -sha256 \
        -extfile "${CERT_DIR}root/SSL-client.ext" \
        -passin pass:$MASTER_PASSWORD > /dev/null 2>&1
    echo -e "."

    # Set the client certificate permissions.
    chmod 644 ${CERT_DIR}${1}/${1}-client.crt
    chmod 600 ${CERT_DIR}${1}/${1}-client.key

}

if [ ! -d "${CERT_DIR}root" ]; then
    # Create the root CA.
    generate_root_ca
fi

if [ ! -f "${WEB_CONF_DIR}site.conf" ]; then
    populate ${WEB_CONF_DIR}site.conf.template ${WEB_CONF_DIR}site.conf $SERVER_NAME
fi

if [ ! -d "${CERT_DIR}${1}" ]; then

	echo -e "\033[01;91mNo ${1} certificates detected.\033[0;0m"

    # Generate the services certificates.
    generate_service_cert $1 $2

	if [ ! $? -eq 0 ]; then
		echo -e "\033[01;91mFailed to generate ${1} certificates.\033[0;0m"
		exit
	fi

fi