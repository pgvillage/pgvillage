#!/bin/bash
set -e

echo Setup git
ssh-keyscan -H github.com >>~/.ssh/known_hosts
sudo zypper install -y --allow-downgrade git pkg-config which
if [ ! -d ~/git/pgv_azure ]; then
	mkdir -p ~/git && cd ~/git && git clone https://github.com/pgvillage/pgv_azure
fi
if [ ! -d ~/git/pgvillage ]; then
	mkdir -p ~/git && cd ~/git && git clone https://github.com/pgvillage/pgvillage && cd pgvillage && ln -s ~/git/pgv_azure/environments .
fi

#echo Install rust
#if ! rustup update; then
#	cd "$(mktemp -d)"
#	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs >sh.rustup.rs
#	bash ./sh.rustup.rs -y
#	export PATH=$HOME/.cargo/bin:$PATH
#fi

cd

echo Install python3
# For more info, see https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html
sudo zypper install -y python3-pip libffi-devel
pip3 install virtualenv
. ~/.bashrc
if ! [ -e ~/venv ]; then
	mkdir ~/venv
	virtualenv ~/venv
	. ~/venv/bin/activate
	echo . ~/venv/bin/activate >>~/.bashrc
fi

echo Install ansible
pip3 install pip ansible azure-cli cryptography azure-identity packaging netaddr msgraph-sdk
ansible-galaxy collection install azure.azcollection
ansible-galaxy role       install --role-file         ~/git/pgvillage/requirements.yml
ansible-galaxy collection install --requirements-file ~/git/pgvillage/requirements.yml
pip3 install -r ~/venv/lib/python3*/site-packages/ansible_collections/azure/azcollection/requirements.txt

echo Setup ssh localhost
[ -f ~/.ssh/id_rsa.pub ] || ssh-keygen -q -f ~/.ssh/id_rsa -P ""
grep -q "$USER@$HOSTNAME" ~/.ssh/authorized_keys || cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
ssh-keygen -H -F localhost >/dev/null || ssh-keyscan -H localhost >>~/.ssh/known_hosts

which ansible-playbook >/dev/null || echo 'Please reload your profile to have ansible-playbook in your path (probably logout/login or `source ~/.bashrc`)'
