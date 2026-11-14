---
title: Preflight
summary: The checks of preflight.yml, which runs before every deploy, what each problem means and how to fix it
---

# Preflight

`preflight.yml` checks your hosts and your inventory before a deploy: the groups, the OS, access, disks, names,
repositories, the network interface, the VIP, memory, time sync and the secrets. It runs all checks, then reports
every problem at once:

- **FAIL**: the deploy would fail or give a broken cluster. Preflight fails, and so does the deploy.
- **WARN**: allowed, but check it. Preflight goes on.

Preflight is read-only: it changes nothing on the hosts, and works with `--check`. (The repository check refreshes
the package lists into a temporary folder, which it removes right after.)

## Running it

`functional-all.yml` runs the checks as its first step (`preflight`, see [Steps](roles.md)), so every deploy starts
with them and stops before it changes anything when one fails. Run them on their own with the same inventories as the
deploy:

```bash
ansible-playbook -i inventories/standard -i inventories/<os> -i inventories/<yours> preflight.yml
```

The report looks like this; every line ends with a link to the section on this page that explains it:

```text
Preflight: 2 failed, 1 warnings, on 4 hosts
FAIL [groups] etcd_master has 2 hosts; etcd needs an odd number (1, 3, 5, ...) (https://.../preflight/#groups)
FAIL [secrets] minio_access_key is still the placeholder of inventories/standard; set your own key (...#secrets)
WARN [disks] db-1: cluster1: data and wal are on the same file system (/) (...#disks)
```

## Skipping checks

Skip a check that doesn't apply to you with `preflight_skip` in your inventory, with the names between `[]` in the
report (`groups`, `os`, `disks`, `names`, `repos`, `interface`, `vip`, `vip_in_use`, `memory`, `timesync`, `secrets`):

```yaml
# group_vars/all/preflight.yml
preflight_skip: [repos]
```

Skip all checks of a deploy with `--skip-tags preflight`, or always with the step setting:

```yaml
pgvillage_roles:
  preflight: { enabled: false }
```

Other settings: `preflight_supported_os` (replaces the list of supported OS versions, see [OS](#os)) and
`preflight_min_memory_mb` (default 1800, see [Memory](#memory)).

## The checks

The checks of the hosts run on the hosts PgVillage deploys on: those in `hacluster`, `backup`, `router`,
`etcd_master`, `stolon` and `haproxy`.

### Groups

FAIL when:

- `etcd_master` has an even number of hosts (0, 2, 4, ...): etcd needs a majority of its members, so it needs an odd
  number (1, 3, 5, ...). By default `etcd_master` is `hacluster`, so this is about the database hosts too.
- `hacluster` has no hosts.
- `backup` has more than 1 host. It has 1 (the backup host with RustFS) or 0 (the backups go to a bucket elsewhere,
  e.g. in Azure). Several RustFS hosts are not supported.
- `localhost` is not in the inventory. The control node creates the certificates, and `localhost` sets the cluster
  name (the folder of the inventory). Add it to `localhosts` in the `hosts` file of your inventory, as in
  `inventories/lima/hosts`.

See [Group names](group-names.md).

### Access

FAIL when Ansible can't log in on a host over ssh, or can't become root with sudo. The report has the error of ssh or
sudo. When sudo asks for a password, run `ansible-playbook` with `--ask-become-pass`; when the user on the hosts
differs from yours, see [Ansible config](ansible_cfg.md).

In `functional-all.yml`, a host that can't be reached already fails when the play gathers its facts: the report then
says "not reached", and the error is above it.

### OS

FAIL when a host runs an OS version or architecture that PgVillage doesn't support, or when the hosts differ in OS
family (e.g. EL and Debian) or architecture (`x86_64` and `aarch64`). The supported versions are those of
[Supported platforms](../platforms/index.md#supported-platforms):

| Distribution                     | Versions                       |
|----------------------------------|--------------------------------|
| Debian                           | 12, 13                         |
| Ubuntu                           | 22.04, 24.04, 26.04, 26.10     |
| EL (RHEL, Rocky, AlmaLinux, ...) | 8, 9, 10                       |
| Fedora                           | 43, 44                         |
| openSUSE Leap                    | 16                             |

To deploy on another version anyway (at your own risk), set your own list, keyed by `ansible_distribution` (`EL` for
RHEL and its rebuilds), with versions as `ansible_distribution_version` or `ansible_distribution_major_version`:

```yaml
preflight_supported_os:
  EL: ['9']
  Debian: ['12', '13']
```

### Disks

On the database hosts, per cluster in `stolon_clusters`:

- FAIL when `postgresql_data_mountpoint` or `postgresql_wal_mountpoint` (`/data/postgres/data`,
  `/data/postgres/wal`) doesn't exist. PgVillage doesn't create file systems or mount disks.
- FAIL when the data folder (`pgdata_dir`) or the wal folder (`pgwal_dir`) of a cluster is a mount point itself, or is
  `postgresql_data_mountpoint`, the `data_dir` of the cluster, `postgresql_wal_mountpoint` or `stolon_wal_dir`. They must
  be subfolders of the mount points: stolon removes and recreates them.
- WARN when the wal folder is `<stolon_wal_dir>/<cluster>`, where the wal disk of the cluster goes: put the wal in a
  subfolder (`<stolon_wal_dir>/<cluster>/wal`, as in `inventories/standard`).
- WARN when the data and the wal of a cluster are on the same file system. Fine for a test, but a full wal disk then
  fills the data too.

See [Disks](../platforms/byo.md#disks).

### Names

FAIL when a host can't resolve the name (FQDN) of another host, or of the backup host (the S3 endpoint of wal-g). The
certificates, etcd and wal-g use these names. Add them to DNS or to `/etc/hosts` on every host.

### Repositories

FAIL when a package repository can't be reached:

- the repositories configured on the host (apt sources, dnf repositories, e.g. of RedHat Satellite or a mirror, and
  zypper repositories): the package manager refreshes them, and the report shows its errors;
- the repositories in the inventory (`linux_public_repos`, which the linux role adds), or when the inventory doesn't
  set it, the servers of the default repositories: `repo.pgvillage.org` and `download.postgresql.org`
  (`apt.postgresql.org` on Debian and Ubuntu).

A host without repositories passes. Check the URL, a proxy (`http_proxy`, `https_proxy`) and the firewall between the
host and the repository.

### Interface

WARN when a host has several IPv4 interfaces (besides loopback) and the inventory doesn't choose one
(`etcd_iface_cluster`, or `stolon_pg_listen_address`): PgVillage then uses the interface of the default route, which may
not be the network between the hosts. See
[More than one network interface](../platforms/index.md#more-than-one-network-interface).

### VIP

Only when `keepalived_vip` is set and `router` has hosts (a router without keepalived is possible: leave
`keepalived_vip` unset, or disable the `keepalived` step). FAIL when:

- the VIP isn't in the subnet of the router hosts (of `keepalived_interface` when it is set);
- the VIP is in use: it answers a ping, or is in the ARP table, while none of the router hosts has it. After a deploy,
  keepalived has the VIP on one of the router hosts: that is fine.

See [Router](../platforms/index.md#router).

### Memory

WARN when a database host has less than 2 GB memory (`preflight_min_memory_mb`, default 1800 MB: a 2 GB VM shows a
bit less, as the kernel keeps some).

### Time sync

WARN when no time sync service (chronyd, systemd-timesyncd, ntpd) runs on a host. etcd, the certificates and the
backups need the right time on all hosts.

### Secrets

FAIL when the S3 keys of the backup host (`minio_access_key`, `minio_secret_key`, or `rustfs_access_key`,
`rustfs_secret_key`) are still the placeholders of `inventories/standard` (`AWSKEY`, `AWSSECRET`). Only when `backup`
has a host.

Set your own keys in your inventory. How you keep them secret is up to you, e.g.:

- [ansible-vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html): an encrypted variable or file in
  your inventory, and `--ask-vault-pass` (or `--vault-password-file`) when you deploy:

    ```bash
    ansible-vault encrypt_string --name minio_secret_key '<a long random secret>'
    ```

- a lookup from [HashiCorp Vault](https://docs.ansible.com/ansible/latest/collections/community/hashi_vault/hashi_vault_lookup.html):

    ```yaml
    minio_secret_key: "{{ lookup('community.hashi_vault.hashi_vault', 'secret=secret/data/pgvillage:s3_secret') }}"
    ```

- or any other lookup or vars plugin your organization uses.

The inventories of the demo platforms (`inventories/lima`, `inventories/vagrant`) set fixed demo keys, so the demos
work out of the box: never use those keys, or those inventories, for anything else.
