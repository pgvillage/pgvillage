---
title: Custom group names
summary: Running PgVillage with custom inventory group names
authors:
  - Sebas Mannem
date: 2026-10-08
---

# Custom group names

The default inventory group names chosen for PgVillage are:

- `hacluster`: This group should hold all PostgreSQL database nodes and will receive PostgreSQL, Stolon, WAL-G and other database server tooling.
- `backup`: This group can have one backup server. PgVillage will deploy MinIO on it, to be used as an S3 endpoint.
- `router`: All servers in this group will receive HAProxy, Keepalived and PgRoute66.

!!! note
    The servers in the `router` group can be the same servers as in the `hacluster` group.

Should you want to use custom group names, you can do so with a few inventory and playbook changes.

## Running with custom group names

In this example, we change to the following group names:

- `hacluster` > `pgnodes`
- `backup` > `minio`
- `router` > `pgroute66`

### Step 1: Override role group names

Some roles have a parameter to set the inventory group of the database nodes.
The reference inventories set these to `hacluster`.
Set them in your inventory to the new group name instead:

!!! example
    ```yaml
    etcd_master_group_name: pgnodes
    pgroute66_pgnodes_group: pgnodes
    stolon_host_group: pgnodes
    chainsmith_nodes: "{{ groups.pgnodes + groups.minio }}"
    ```

### Step 2: Update values with group names as keys

Some values are dictionaries with group names as keys.
One example is `linux_packages`, which sets the specific packages to be installed on `hacluster` nodes, `backup` nodes, etc.
If you have already overridden them in your inventory, update the keys.
If not, copy them from the roles, update them and add them to your inventory.

List of values containing group names as keys:

- `chainsmith_users`
- `linux_groups`
- `linux_packages`
- `linux_rhsm_poolids` (only when using RHSM)
- `linux_users`

!!! warning
    `linux_packages` is derived from internal variables (`_linux_packages`) in the linux role.
    When overriding it, make sure the resulting dictionary contains all packages (including the PostgreSQL packages) under the new group names.

### Step 3: Move group specific inventory config

The reference inventories also contain config specific for servers in certain groups.
As the group names have changed, these folders need to be renamed as well.

!!! example
    ```bash
    mv environments/{ENV}/group_vars/{hacluster,pgnodes}
    mv environments/{ENV}/group_vars/{backup,minio}
    mv environments/{ENV}/group_vars/{router,pgroute66}
    ```

### Step 4: Update the hosts file

The new groups should be known to Ansible.
Update the hosts file (`environments/{ENV}/hosts`) as required.

### Step 5: Update the playbooks

The new groups should be properly referred to in the playbooks.
Update the following as required:

- `functional-all.yml`: the `hosts:` lists of all plays
- `rollout_new_certs.yml`: the `hosts:` lists of all plays
- `uninstall.yml`: the `when:` condition referring to `groups['hacluster']` and `groups['router']`

!!! example
    ```bash
    for PB in functional-all.yml rollout_new_certs.yml uninstall.yml; do
      sed -i.bak \
        -e 's/hacluster/pgnodes/g' \
        -e 's/backup/minio/g' \
        -e 's/router/pgroute66/g' \
        "${PB}"
    done
    ```

!!! warning
    The above example is a crude instrument, and also changes tags and task names (e.g. `backup`).
    It is better to update the playbooks manually, and review the changes (e.g. with `git diff`) either way.
