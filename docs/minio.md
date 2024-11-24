# Introduction

The standard building block makes backups using WAL-G and WAL-G stores the backups in Cloud Storage (buckets).

Within Acme, however, there is no Cloud Storage available and therefore MinIO is deployed so that WAL-G can subsequently transport the backups to MinIO so that they:

---

- Stored outside the database server.
- All cluster nodes use a shared backup medium.
- The file system behind MinIO can be easily included in CommVault via VM Backup.

This means that MinIO can be replaced by a future Cloud Storage (bucket) system once it becomes available within Acme.

# Benodigdheden

Voor minio zijn de volgende componenten nodig:

- MinIO and mcli are both run on a separate backup server (e.g., acme-dvppg1 **bc**-server1)
- Server:
  - The binary is deployed to /usr/local/bin/ using the RPMs
    - Source for the minio RPM: [https://dl.min.io/server/minio/release/linux-amd64](https://dl.min.io/server/minio/release/linux-amd64)
  - The service file /etc/systemd/system/minio.service is created and maintained by Ansible
  - The configuration (/etc/default/minio) is deployed and maintained by Ansible
  - TLS certificates (/etc/pki/tls/minio/*) are deployed and maintained by Ansible
    - The root certificate is made available to wal-g by Ansible
  - Runs on port 9091 (default)
  - Stores data in /data/postgres/backup/
- Client (mcli):
  - Used by Ansible to create the bucket
  - Also configured by Ansible (under the minio-server user)
  - The binary is deployed to /usr/local/bin/ using the RPMs
    - Source for the mcli RPM: [https://dl.min.io/client/mc/release/linux-amd64](https://dl.min.io/client/mc/release/linux-amd64)

## Usage

In principe wordt alles uitgerold en onderhouden middels Ansible.

If more insight is desired, two things can be done:

1.
2.

1: Ensure routing to the management console (SSH proxy, opening ports in the firewall, etc.).

You can then use a browser to connect to this port and browse through the bucket (MinIO).

2: (Advice) Use `mcli` on the backup server under the `minio-user` account:

-

```markdown
me@gurus-dbabh-server1 ~/g/ansible-postgres (tmp)> ssh acme-dvppg1bc-server1.acme.corp.com
```

```markdown
Last login: Thu Oct 13 21:12:47 2022 from 10.0.6.100
```

```markdown
[me@acme-dvppg1bc-server1 ~] $ sudo -i uminio-user
```

```markdown
[minio-user@acme-dvppg1bc-server1 ~]$ /usr/local/bin/mcli ls minio/backup/basebackups_005/
```

```markdown
[2022-10-11 16:54:12 CEST] 404B STANDARD base_000000010000000C0000000E_backup_stop_sentinel.json
```

```
[2022-10-12 09:08:48 CEST]   530B STANDARD base_000000010000000E00000069_D_000000010000000C0000000E_backup_stop_sentinel.json
```

```
[2022-10-12 09:29:37 CEST]     404B STANDARD base_000000010000000E0000006B_backup_stop_sentinel.json
```

```
[2022-10-12 20:02:06 CEST]   528B STANDARD base_000000010000000E0000006E_D_000000010000000E0000006B_backup_stop_sentinel.json
```

```markdown
[2022-10-13 20:02:17 CEST]   559B STANDARD base_000000010000001000000046_D_000000010000000E0000006E_backup_stop_sentinel.json
```

```markdown
[2022-10-13 21:31:56 CEST]    0B base_000000010000000C0000000E/
```

```
[2022-10-13 21:31:56 CEST]     0B base_000000010000000E00000069_D_000000010000000C0000000E/
```

```
[2022-10-13 21:31:56 CEST]    0B base_000000010000000E0000006B/
```

```markdown
[2022-10-13 19:31:56 UTC]    0B base_000000010000000E0000006E_D_000000010000000E0000006B/
```

```markdown
[2022-10-13 19:31:56 UTC]     0B base_000000010000001000000046_D_000000010000000E0000006E/
```

# Tips & tricks

When files are deleted, they are temporarily stored in a temporary folder for a certain period of time.

Deze tijdelijke map wordt iedere 24 uur geschoond en schoond alles wat 24 uur of langer geleden is weg gegooid.

In theory, this temporary data can therefore be cleaned up 47 hours later (if everything turns out to be a bit annoying).

In principle, the sizing of the storage behind MinIO is sufficiently sized, but if it becomes important to clean up this temporary data,

```

(bijvoorbeeld omdat je schijfruimte vrij wilt maken door backups op te schonen), dan kan deze worden geschoond door de minio service te herstarten:

```markdown
[me@acme-dvppg1bc-server1 ~]$ sudo systemctl restart minio.service
```

This only affects a backup and restore (they need to be restarted).

---

Recovery (wal-fetch) and archiving (wal-push) are simply replayed and are not impacted by a MinIO restart.

```markdown
Recovery (wal-fetch) and archiving (wal-push) are simply replayed and are not impacted by a MinIO restart.
```
```

