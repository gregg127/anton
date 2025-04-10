#!/bin/bash

# Script: manage-secrets.sh
# Usage: ./manage-secrets.sh encrypt|decrypt <file>

# Check for required arguments
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 encrypt|decrypt <file>"
  exit 1
fi

operation=$1
file=$2

# Check if file exists
if [ ! -f "$file" ]; then
  echo "Error: File '$file' not found."
  exit 1
fi

# Perform operation
case "$operation" in
  encrypt)
    gpg --yes --output "${file}.gpg" --encrypt --recipient CA40D3A0 "$file"
    echo "Encrypted: ${file}.gpg"
    ;;
  decrypt)
    if [[ "$file" != *.gpg ]]; then
      echo "Error: Decryption expects a .gpg file."
      exit 1
    fi
    output_file="${file%.gpg}"
    gpg --yes --output "$output_file" --decrypt "$file"
    echo "Decrypted: $output_file"
    ;;
  *)
    echo "Invalid operation: $operation"
    echo "Use 'encrypt' or 'decrypt'"
    exit 1
    ;;
esac