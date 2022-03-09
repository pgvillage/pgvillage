#!/bin/bash
set -e

cd "$(dirname $0)"/..
PROJDIR=$PWD

mkdir -p tmp
ENV=${1}
export CHAINSMITH_HOSTS="./environments/${ENV}/hosts"
if [ ! -e "${CHAINSMITH_HOSTS}" ]; then
  echo -e "Ongeldige omgeving meegegeven.\nAanroep: $0 \${ENV}"
  exit 1
fi

export CHAINSMITH_TMPDIR=$(mktemp -d)
echo "Tijdelijke data in ${CHAINSMITH_TMPDIR}"

export CHAINSMITH_CONFIG="./config/${ENV}.yml"
[ -e "${CHAINSMITH_CONFIG}" ] || export CHAINSMITH_CONFIG=./config/chainsmith.yml
CONFPATH="./environments/${ENV}/group_vars/all"
mkdir -p "${CONFPATH}"

export CHAINSMITH_CERTSPATH="${CONFPATH}/certs.yml"
export CHAINSMITH_PRIVATEKEYSPATH="${CONFPATH}/certsvault.yml"
if [ -e "${CHAINSMITH_CERTSPATH}" -o -e "${CHAINSMITH_PRIVATEKEYSPATH}" ]; then
  echo -e "Destination files already exist.\n- ${CHAINSMITH_CERTSPATH}\n- ${CHAINSMITH_PRIVATEKEYSPATH}\n\nRemove and restart if you want to replace them."
  exit 1
fi

chainsmith

[ -z "${ANSIBLE_VAULT_PASSWORD_FILE}" ] && export ANSIBLE_VAULT_PASSWORD_FILE=bin/gpgvault
ansible-vault encrypt "${CHAINSMITH_PRIVATEKEYSPATH}"

TARFILE=${PROJDIR}/tmp/poc.csr.tar
echo "Creating tar file with all Certificate Sigining Requests: ${TARFILE}"
rm -f "${TARFILE}" "${TARFILE}.gz"
cd "${CHAINSMITH_TMPDIR}"
find -name '*.csr' | xargs tar -cvf "${TARFILE}"
gzip "${TARFILE}"

echo "Cleaning tmp files (scrambling and then removing)"
cd "${CHAINSMITH_TMPDIR}"
find "tls" -type f | xargs shred -z -u
rm -rf "${CHAINSMITH_TMPDIR}"

echo "Finished succesfully"
