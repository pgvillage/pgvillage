# pg Village

Run a 100% Open Source awesome PostgreSQL solution

## TL;DR

To get going on Azure:

- Create an azure VM (this will be the bootstrap host to run Ansible creating the environments):
  ```
  az group create --name pgVillage --location westeurope
  az vm create \
    --resource-group pgVillage \
    --name pgVControl \
    --image Debian11 \
    --admin-username azureuser \
    --generate-ssh-keys \
    --tags applicationRole=ansible_runner
  ```
  **Notes**:
  - VMSize B1ls seems too small. Running with B1s works properly.
  - You can also use this image: `--image susellc:opensuse-leap-x86-64:gen2:2026.04.01`

- log into it:
  ```
  ssh azureuser@$(az vm show -d -g pgVillage -n pgVControl --query publicIps -o tsv)
  ```

- bootstrap it into aPgVillage Ansible Control Node
  ```bash
  curl https://raw.githubusercontent.com/pgvillage/pgv_azure/main/bootstrap_debian.sh | bash
  ```
  or for suse:
  ```bash
  curl https://raw.githubusercontent.com/pgvillage/pgv_azure/main/bootstrap_suse.sh | bash
  ```

  **Note** that for Suse there is less builds on download.postgresql.org available
  (at the time of this writing, this is only for leap-16 on x86_64 for openSuse, and
  sles15/16 on x86_64 for Suse). We only build rpm's for leap/16 on x86_64. If you need
  other architectures, or specific Suse builds please reach out to us.

- The VM will use the azure API to create database VM's t will.
  Log in to azure on the VM too: `az login`.
  **note** at the time of writing this doc, azure-cli was not compatiable with the azure_rm modules.
  Therefore we created `az_to_env`, which would create another virtual env for `az`, download it, login and then generate azure_creds.env.
  After which you can run `. azure_creds.env`, and then run ansible with azure authentication.

- Further deployment can be done with:
  ```bash
  ~/git/pgv_azure/create_new_cluster.sh
  ```

## Alternate

- Create a CentOS VM Ansible Control Node on Azure by following [this](https://docs.microsoft.com/en-us/azure/developer/ansible/install-on-linux-vm?tabs=azure-cli#install-ansible-on-an-azure-linux-virtual-machine).
- After that you need to manually do all things in the bootstrap script (no script available yet).
- Then you can create credentials, accept and follow instructions as described above.

## Using other images

1. Find the publisher, the offer and the urn of the image to use:
   (in this example we use [resf](https://forums.rockylinux.org/t/rocky-linux-images-on-azure-important-update/13721))
   ```bash
   az vm image list-publishers --location westeurope --output table
   az vm image list --output table --all --publisher resf
   az vm image list --publisher resf --offer rockylinux-aarch64 --all --output table
   ```

3. Accept the license:
   ```bash
   az vm image terms accept --publisher resf --offer rockylinux-x86_64 --plan 9-lvm
   ```

4. change the inventory to use this VM as bastion and/or vmss (replace fields in [] with corresponding columns of command).
   (See [environments/cluster2/group_vars/all/azure.yml](environments/cluster2/group_vars/all/azure.yml) for an example) 
   ```
   azure_vmss_image:
     offer: [Offer]
     publisher: [Publisher]
     version: [Version]
     sku: [Sku]
   azure_vmss_plan:
     name: [Sku]
     product: [Offer]
     publisher: [Publisher]
   ```

## Known issues and quirks

- VMSize B1ls seems too small for pgVControl. Running with B1s seems to work good ATM.
- You might (every now and then) wanna upgrade the ansible code, bootstrap script and python modules:

```
cd ~/git/pgv_azure/
git pull
./bootstrap_debian.sh
```

- ./roles/anzure/defaults/main.yml has a value azure_storage_account_name which is derived from clustername and machine_id of controlnode. This means it is pretty much unique across azure (which is the idea), but also means it might change during reboots, and will change across ansible control nodes. For PRODUCTION always set this to a unique but hardcoded value insted!!!
- When rerunning, the vmss module cries about 'The orchestration_mode parameter cannot be updated!'. This probably should be fixed by the ansible community
- If the VM Scaleset uses a different image then the bastion, you need to accept Rocky linux image terms (e.a.)

```
az vm image terms accept --urn resf:rockylinux-x86_64:9-base:9.6.20250531
```

## Clusters

Please check descriptions on the deployments that we have pre-configured for you:
- [cluster1](./environments/cluster1/README.md)
- [cluster2](./environments/cluster2/README.md)
- [cluster3](./environments/cluster3/README.md)
