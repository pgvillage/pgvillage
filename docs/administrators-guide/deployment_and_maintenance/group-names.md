---
title: Custom group names
summary: Running with custom group names
authors:
  - Sebas Mannem
date: 2026-10-08
---

# Group names

The default group names chosen for PgVillage are:

- hacluster: This group should hold all PostgreSQL database nodes and will receive postgres, stolon, wal-g and other database server tooling.
- backup: This group can have one backup server. PgVillage will deploy Minio to be used as an S3 endpoint.
- router: All servers in this group will have HaProxy, KeepAliveD and PgRoute66. **note** this can be the same servers as hacluster.

Should you however want to use custom group names, you can do this with a few simple inventory changes.

## Running with custom group names

In this example, we change to the following group names:

- hacluster > postgres
- backup > minio
- router > pgroute66

### Step 1: Override role group names

Some roles have a special parameter to ste the group name for postgres nodes (defaulting to hacluster).
Set them in your inventory to the new group name instead:

!!! example
    ```yaml
    chainsmith_node_group: pgnodes
    etcd_master_group_name: pgnodes
    pgroute66_pgnodes_group: pgnodes
    stolon_host_group: pgnodes
    ```

### Step 2: Override role defaults using direct group names

Some values in the PgVillage roles default to jinja based on the default group names.
These values should be overwritten with new group names.
Best approach is to copy the defaults from the roles to the inventory and override group names.
These are the values to override in your inventory:


!!! example
    ```yaml
    avchecker_cluster_members: "{% set nodes = [] %}{% for node in groups.pgnodes %}{% do nodes.append(hostvars[node].ansible_facts.fqdn) %}{% endfor %}{{ nodes | list | join(',') }}"

    chainsmith_nodes: "{% set nodes = [] %}{% for node in (groups.pgnodes + groups.minio) %}{% do nodes.append(hostvars[node].ansible_facts.fqdn) %}{% endfor %}{{ nodes }}"
    chainsmith_ips: "{% set nodes = [] %}{% for node in (groups.pgnodes + groups.minio) %}{% do nodes.append(hostvars[node].ansible_host) %}{% endfor %}{{ nodes }}"
    chainsmith_servers: "{% set nodes = {} %}{% for node in (groups.pgnodes + groups.minio) %}{% do nodes.update({hostvars[node].ansible_facts.fqdn: chainsmith_nodes+chainsmith_ips}) %}{% endfor %}{{ nodes }}"
    ```

!!! note
    ```yaml
    Above is only an example. Make sure you copy the exact contents from the `defaults/main.yml` files for the specified roles
    ```

### Step 3: Update defaults with group names as keys

Some inventory values use group names as keys. One example is linux_packages, which sets the specific packages to be installed on hacluster nodes, minio nodes, etc.
If you have alredy overriden them, you should update them. If not, copy them from the roles, and update them as you have also done for `Step 2`.

List of values containing group names:
- chainsmith_users
- linux_users
- linux_packages
- linux_groups

### Step 4: Move group specific inventory config

In our inventory examples, we also set some config specific for servers in certain groups.
As the group names have changed, the folders need to be renamed as well.

!!! example
    ```bash
    mv environments/cluster1/group_vars/{hacluster,pgnodes}
    mv environments/cluster1/group_vars/{backup,minio}
    mv environments/cluster1/group_vars/{router,pgroute66}
    ```

### Step 5: Update the hosts file

The new groups should be known to Ansible. Update the hosts file as required.

- environments/cluster1/hosts

### Step 6: Update the playbooks

The new groups should be properly referred to in the playbooks.
Update them as required:


!!! example
    ```bash
    for PB in functional-all.yml rollout_new_certs.yml uninstall.yml; do
      sed -i 's/hacluster/pgnodes/' "${PB}"
      sed -i 's/backup/minio/' "${PB}"
      sed -i 's/router/pgroute66/' "${PB}"
    ```

!!! note

    The above example is a crude instrument, and also updates some tags. Best is to update manually.
