#!/bin/bash
set -e

# hotfix for bullsey
echo 'deb http://debian-archive.trafficmanager.net/debian bullseye main
deb-src http://debian-archive.trafficmanager.net/debian bullseye main
#deb http://debian-archive.trafficmanager.net/debian-security bullseye-security main
deb http://security.debian.org/debian-security bullseye-security main
deb-src http://debian-archive.trafficmanager.net/debian-security bullseye-security main
deb http://debian-archive.trafficmanager.net/debian bullseye-updates main
deb-src http://debian-archive.trafficmanager.net/debian bullseye-updates main
#deb http://debian-archive.trafficmanager.net/debian bullseye-backports main
#deb-src http://debian-archive.trafficmanager.net/debian bullseye-backports main' | sudo bash -c 'cat >/etc/apt/sources.list'

echo Setup git
ssh-keyscan -H github.com >>~/.ssh/known_hosts
sudo apt-get update -y && sudo apt-get install -y git apt pkg-config libssl-dev jq
if [ ! -d ~/git/pgv_azure ]; then
	mkdir -p ~/git && cd ~/git && git clone https://github.com/pgvillage/pgv_azure
fi
if [ ! -d ~/git/pgvillage ]; then
	mkdir -p ~/git && cd ~/git && git clone https://github.com/pgvillage/pgvillage && cd pgvillage && ln -s ~/git/pgv_azure/environments .
fi

echo Install rust
if ! rustup update; then
	cd "$(mktemp -d)"
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs >sh.rustup.rs
	bash ./sh.rustup.rs -y
	export PATH=$HOME/.cargo/bin:$PATH
	cd -
fi

cd

echo Install python3
# For more info, see https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html
sudo apt-get install -y python3-pip libffi-dev
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1

echo Install ansible
pip3 install --upgrade --user pip ansible azure-cli-core --upgrade cryptography azure-identity packaging netaddr msgraph-sdk
~/.local/bin/ansible-galaxy collection install azure.azcollection
~/.local/bin/ansible-galaxy role       install --role-file         ~/git/pgvillage/requirements.yml
~/.local/bin/ansible-galaxy collection install --requirements-file ~/git/pgvillage/requirements.yml
pip3 install --user -r ~/.local/lib/python3.9/site-packages/ansible_collections/azure/azcollection/requirements-azure.txt

echo Install chainsmith
cd "$(mktemp -d)"
RELEASE="$(curl 'https://api.github.com/repos/pgvillage-tools/chainsmith/releases/latest' | jq -r ".tag_name")"
curl -L -o chainsmith.tar.gz "https://github.com/pgvillage-tools/chainsmith/releases/download/${RELEASE}/chainsmith_${RELEASE}_linux_amd64.tar.gz"
tar -xvf chainsmith.tar.gz
sudo mv chainsmith /usr/local/bin
cd

echo Install az
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
# workaround regarding `Can't get attribute 'NormalizedResponse' on <module 'msal.throttled_http_client'`
az config set core.use_msal_http_cache=false

echo Setup ssh localhost
[ -f ~/.ssh/id_rsa.pub ] || ssh-keygen -q -f ~/.ssh/id_rsa -P ""
grep -q "$USER@$HOSTNAME" ~/.ssh/authorized_keys || cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
ssh-keygen -H -F localhost >/dev/null || ssh-keyscan -H localhost >>~/.ssh/known_hosts

# shellcheck disable=SC2016
which ansible-playbook >/dev/null || echo 'Please reload your profile to have ansible-playbook in your path (probably logout/login or `source ~/.profile`)'
