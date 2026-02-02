#!/bin/bash

# Script: manage-secrets-sops.sh
# Usage: ./manage-secrets-sops.sh encrypt|decrypt <file>

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
    sops --encrypt --in-place "$file"
    ;;
  decrypt)
    sops --decrypt --in-place "$file"
    ;;
  *)
    echo "Invalid operation: $operation"
    echo "Use 'encrypt' or 'decrypt'"
    exit 1
    ;;
esac