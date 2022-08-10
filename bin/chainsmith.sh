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

export CHAINSMITH_CONFIG="./config/chainsmith_${ENV}.yml"
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

if [ -z "${CHAINSMITH_DONTVAULT}" ]; then
  [ -z "${ANSIBLE_VAULT_PASSWORD_FILE}" ] && export ANSIBLE_VAULT_PASSWORD_FILE=bin/gpgvault
  ansible-vault encrypt "${CHAINSMITH_PRIVATEKEYSPATH}"
else
  echo "Please encrypt the Ansible Vault manually (e.a. \`ansible-vault encrypt '${CHAINSMITH_PRIVATEKEYSPATH}'\`)"
fi

CSRTARFILE=${PROJDIR}/tmp/${ENV}.csr.tar
echo "Creating tar file with all Certificate Sigining Requests: ${CSRTARFILE}.gz"
rm -f "${CSRTARFILE}" "${CSRTARFILE}.gz"
cd "${CHAINSMITH_TMPDIR}"
find -name '*.csr' | xargs tar -cvf "${CSRTARFILE}"
gzip "${CSRTARFILE}"

if [ -z "${CHAINSMITH_DONTGPG}" ]; then
  CCTARFILE=${PROJDIR}/tmp/${ENV}.clientcerts.tar.gpg
  echo "Creating gpg tar'ed file with all client certs and keys: ${CCTARFILE}"
  find -regex '.*\.\(crt\|pem\|pk8\|der\)' | xargs tar -cv | gzip | gpg --symmetric --output "${CCTARFILE}"
fi

if [ -z "${CHAINSMITH_DONTSHRED}" ]; then
  echo "Cleaning tmp files (scrambling and then removing)"
  cd "${CHAINSMITH_TMPDIR}"
  find "tls" -type f | xargs shred -z -u
  rm -rf "${CHAINSMITH_TMPDIR}"
else
  echo "Please shred all files in ${CHAINSMITH_TMPDIR} manually (e.a. \`find '${CHAINSMITH_TMPDIR}/tls' -type f | xargs shred -z -u ;  rm -rf '${CHAINSMITH_TMPDIR}'\`"
fi

echo "Finished succesfully"
