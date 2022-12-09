#!/bin/bash
set -e
CHAINSMITH_CERT_LIST=${CHAINSMITH_CERT_LIST:-/tmp/chainsmith_cert_list.txt}
CHAINSMITH_EXPIRY_DAYS=${CHAINSMITH_EXPIRY_DAYS:-30}

if [ ! -e "${CHAINSMITH_CERT_LIST}" ]; then
  echo "File ${CHAINSMITH_CERT_LIST} does not exists"
  exit 1
else
  cat "${CHAINSMITH_CERT_LIST}" | while read CERT_FILE; do
    echo -n "${CERT_FILE}: "
    openssl x509 -checkend "$((CHAINSMITH_EXPIRY_DAYS*86400))" -noout -in "${CERT_FILE}"
  done
fi
echo "All seem ok"
