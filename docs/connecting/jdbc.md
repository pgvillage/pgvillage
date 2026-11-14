# JDBC Introduction

The JDBC client can be configured with a JDBC URL.

This work instruction provides some suggestions for the format.

The SSL parameters are included (for convenience).

## Instruction

Some examples of JDB URLs:

```bash
#rw:
postgres://{user}@{db hosts separated by ,}:5432/{database name}?sslmode=verify-full&sslcert=/home/{user}/.postgresql/{user}.crt&sslkey=/home/{user}/.postgresql/{user}.key&sslrootcert=/home/{user}/.postgresql/root.crt

#proxy:
postgres://{user}@{db hosts separated by ,}:25432/{database name}?sslmode=verify-full&sslcert=/home/{user}/.postgresql/{user}.crt&sslkey=/home/{user}/.postgresql/{user}.key&sslrootcert=/home/{user}/.postgresql/root.crt

#vip_rw:
postgres://{user}@{vip fqdn}:5432/{database name}?sslmode=verify-full&sslcert=/home/{user}/.postgresql/{user}.crt&sslkey=/home/{user}/.postgresql/{user}.key&sslrootcert=/home/{user}/.postgresql/root.crt

# vip_ro
postgres://{user}@{vip fqdn}:5433/{database name}?sslmode=verify-full&sslcert=/home/{user}/.postgresql/{user}.crt&sslkey=/home/{user}/.postgresql/{user}.key&sslrootcert=/home/{user}/.postgresql/root.crt
```

Starting point is that:

- `{user}` is replaced by the Postgres user.  
  - This must match the Postgres user.  
  - This must match the Common Name of the client certificate:  

```bash
openssl x509 -text -noout -in /home/{user}/.postgresql/{user}.crt | sed -n '/Subject:/{s/.\*= //;p}'
- {vip fqdn} must be replaced with the IP address of the VIP
- {database name} must be replaced with the name of the Postgres database
- {list of all hosts, separated by ,} must be replaced with a list of the servers, etc.

gurus-pgsdb-server1.int.corp.com, gurus-pgsdb-server2.int.corp.com, gurus-pgsdb-server3.int.corp.com
- The certificate files are indeed stored in the respective subdirectory.
```

