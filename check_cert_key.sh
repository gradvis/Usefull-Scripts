#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <path_to_certificate> <path_to_key>"
    echo "If the certificate and key are located in the current directory and named client.crt and client.key respectively:"
    echo "./check_cert_key.sh client.crt client.key"
    exit 1
fi

# Path to the certificate
CERT_FILE="$1"

# Path to the private key
KEY_FILE="$2"

# Check if the certificate file exists
if [ ! -f "$CERT_FILE" ]; then
    echo "Error: Certificate file '$CERT_FILE' not found."
    exit 1
fi

# Check if the key file exists
if [ ! -f "$KEY_FILE" ]; then
    echo "Error: Key file '$KEY_FILE' not found."
    exit 1
fi

# Extract the hash from the certificate
CERT_HASH=$(openssl x509 -noout -modulus -in "$CERT_FILE" | openssl md5)

# Extract the hash from the private key
KEY_HASH=$(openssl rsa -noout -modulus -in "$KEY_FILE" | openssl md5)

# Compare the hashes
if [ "$CERT_HASH" == "$KEY_HASH" ]; then
    echo "The certificate and key match."
else
    echo "The certificate and key do NOT match."
fi
