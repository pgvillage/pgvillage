## Important

1. In almost all cases, the reason for a point-in-time restore is not due to an error in the PostgreSQL architecture or by the DBA.
```

Daarom is in bijna alle gevallen Point in time Restore ook geen downtime van de dienst.

Take the time to perform a proper Point-in-Time Restore...

2. In a Shared Cluster setup, it's important that a single database is restored while the rest remain available as usual.

Actually, this is not a feature of the standard building block, but it can be executed.

See chapter _Restore of Some Databases or Tables_ for more information.

## Restore to point in time

[WAL-g](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/WAL-g/WebHome.html) supports performing a restore to Point in Time, but the procedure in combination with [stolon](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Stolon/WebHome.html) (High Availability Cluster Management) is complex.

```markdown
That's why it is included in an Ansible playbook, which does the following:
```

- Stop the stolon-keeper on all nodes  
- Remove the Postgres data and recreate the folders with the correct permissions  
- Generate the stolon custom\_config required to perform a Point In Time Restore using stolon and wal-g  
- Load the custom\_config into the etcd config of stolon  
- Start stolon-keeper (one by one per node)  
  - Stolon starts on the master and  
    - Finds pitr as the init mode and executes the restore script.  
      - The restore script runs wal-g backup-fetch to restore data to the last backup for the point in time  
    - Starts Postgres afterwards, which performs recovery up to a specific point in time  
      - Uses the restore\_command to retrieve WAL-files using wal-g  
      - Once Postgres is done with recovery (up to the point in time), PostgreSQL becomes available  
  - PostgreSQL is again available for the application  
  - Meanwhile, the standbys start, they clone from the master and become ReadOnly available

## Performance

Point-in-time restore can be executed from the management server:

1: go via SSH to the management server

```markdown
2: Ensure a good Ansible configuration: [Ansible](../../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/ansible/WebHome.html)
```

3: voer Point in Time restore uit middels Ansible. Een paar voorbeelden:

```markdown
cd ~/git/ansible-postgres
```

```markdown
export ANSIBLE_VAULT_PASSWORD_FILE=$PWD/bin/gpgvault
```

```markdown
# Restore to August 30, 2022 at 09:10:11 AM:
```

```markdown
ansible-playbook -i environments/poc/ ./restore.yml -e 'restore_target="2022-08-30T09:10:11"'
```

```markdown
# Restore to the label mylabel1:
```

```markdown
ansible-playbook -i environments/poc/ ./restore.yml -e restore_target="mylabel1"
```

# Restore to transaction ID 50851

```
ansible-playbook -i environments/poc/ ./restore.yml -e restore_target="50851"
```

For a restore until the last moment, simply do not specify `-e restore_target=...`!

Think about this: The `RESTORETARGETINPUT` is written (appended) to `/etc/default/wal-g`. Even if the restore goes well, it will not be removed! **Check manually and adjust for starting restore.**

Also check for `backup` files in the data directory that are created after a restore on the master and make a backup after the restore!

# ```markdown
Restore some database or table
```

In a Shared Cluster setup, it's important that a single database is restored while the rest remains available.

Eigenlijk is dit geen feature van het standaard bouwblok, maar kan dit wel uitgevoerd worden:

- Make a standby available (stop stolon-keeper as root or with adm account and sudo)  
- Optionally free up or expand disk space there  
- Set PGRESTORE to a value other than PGDATA (etc. export `PGRESTORE=`)  
- Run the restore script with a restoration location, restore target, etc.:

```
/opt/wal-g/scripts/restore.sh "/data/postgres/data/restore" "2022-08-30 09:10:11"
- Start the instance manually, etc.
```

```markdown
/usr/pgsql-12/bin/pg_ctl start -D "/data/postgres/data/restore"
```

**NOTE**: This can be set up alongside an existing instance, as it starts on port 5433!!!

2. Copy the data that needs to be restored to the master instance. For example:
- schema:  
-

```
pg_dump [database] -n [myschema] | psql service=master
- Table (first truncate):
- pg_dump [database] -t "[myschema].[mytable]" | psql service=master
3. Stop the instance, discard the restore data
```

```markdown
/usr/pgsql-12/bin/pg_ctl stop -D "/data/postgres/data/restore"
```

```markdown
rm -rf "/data/postgres/data/restore"  
4. Restart Stolon Keeper (as root or with the `adm` account and `sudo`)  
```

