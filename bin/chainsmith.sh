#!/bin/bash
set -e

cd "$(dirname $0)"/..
PROJDIR=$PWD

mkdir -p tmp
export CHAINSMITH_ENV=${1}
if [ ! -e "./environments/${CHAINSMITH_ENV}/hosts" ]; then
  echo -e "Ongeldige omgeving meegegeven.\nAanroep: $0 \${ENV}"
  exit 1
fi

export CHAINSMITH_TMPPATH=$(mktemp -d)
echo "Tijdelijke data in ${CHAINSMITH_TMPPATH}"

export CHAINSMITH_CONFIG="./config/${CHAINSMITH_ENV}.yml"
[ -e "${CHAINSMITH_CONFIG}" ] || export CHAINSMITH_CONFIG=./config/chainsmith.yml
CONFPATH="./environments/${CHAINSMITH_ENV}/group_vars/all"
mkdir -p "${CONFPATH}"

export CHAINSMITH_CERTSPATH="${CONFPATH}/certs.yml"
export CHAINSMITH_PEMSPATH="${CONFPATH}/certsvault.yml"
if [ -e "${CHAINSMITH_CERTSPATH}" -o -e "${CHAINSMITH_PEMSPATH}" ]; then
  echo -e "Destination files already exist.\n- ${CHAINSMITH_CERTSPATH}\n- ${CHAINSMITH_PEMSPATH}\n\nRemove and restart if you want to replace them."
  exit 1
fi

export CHAINSMITH_LOG="${PROJDIR}/tmp/chainsmith_${CHAINSMITH_ENV}.log"
echo "Chainsmith logging in in ${CHAINSMITH_LOG}"
./bin/chainsmith.py >> "${CHAINSMITH_LOG}" 2>&1

[ -z "${ANSIBLE_VAULT_PASSWORD_FILE}" ] && export ANSIBLE_VAULT_PASSWORD_FILE=bin/gpgvault
ansible-vault encrypt "${CHAINSMITH_PEMSPATH}"

TARFILE=${PROJDIR}/tmp/poc.csr.tar
echo "Creating tar file with all Certificate Sigining Requests: ${TARFILE}"
rm -f "${TARFILE}" "${TARFILE}.gz"
cd "${CHAINSMITH_TMPPATH}"
find -name '*.csr' | xargs tar -cvf "${TARFILE}"
gzip "${TARFILE}"

echo "Cleaning tmp files (scrambling and then removing)"
cd "${CHAINSMITH_TMPPATH}"
find "tls" -type f | xargs shred -z -u
rm -rf "${CHAINSMITH_TMPPATH}"

echo "Finished succesfully"
