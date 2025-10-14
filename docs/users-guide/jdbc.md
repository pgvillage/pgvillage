# Introduction

De jdbc client kan geconfigureerd worden met een jdbc url.

Deze werkinstructie geeft wat suggesties voor de vorm.

The SSL parameters are included (for convenience).

# Dependencies

```markdown
- [server request](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Van+database+aanvraag+naar+server+aanvraag/WebHome.html)
- [set up cluster](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Van+server+naar+draaiende+database/WebHome.html)
- [client connection information](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Clients/WebHome.html)
- [Client certificates](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/Client+certificaten/WebHome.html)
```

# Instruction

Wat voorbeelden vn jdb urls:

#rw:

```
postgres://{user}@{db hosts separated by ,}:5432/{database name}?sslmode=verify-full&sslcert=/home/{user}/.postgresql/{user}.crt&sslkey=/home/{user}/.postgresql/{user}.key&sslrootcert=/home/{user}/.postgresql/root.crt
```

#proxy:

-

```
postgres://{user}@{db hosts separated by ,}:25432/{database name}?sslmode=verify-full&sslcert=/home/{user}/.postgresql/{user}.crt&sslkey=/home/{user}/.postgresql/{user}.key&sslrootcert=/home/{user}/.postgresql/root.crt
```

#vip_rw:

```markdown
postgres://{user}@{vip fqdn}:5432/{database name}?sslmode=verify-full&sslcert=/home/{user}/.postgresql/{user}.crt&sslkey=/home/{user}/.postgresql/{user}.key&sslrootcert=/home/{user}/.postgresql/root.crt
```

## vip_ro

---

```
postgres://{user}@{vip fqdn}:5433/{database name}?sslmode=verify-full&sslcert=/home/{user}/.postgresql/{user}.crt&sslkey=/home/{user}/.postgresql/{user}.key&sslrootcert=/home/{user}/.postgresql/root.crt
```

Starting point is that:

- `{user}` is replaced by the Postgres user.  
  - This must match the Postgres user.  
  - This must match the Common Name of the client certificate:  
-

```markdown
openssl x509 -text -noout -in /home/{user}/.postgresql/{user}.crt | sed -n '/Subject:/{s/.\*= //;p}'
- {vip fqdn} moet vervangen worden door het IP adres van de VIP
- {database name} moet vervangen werden door de naam van de Postgres Database
- {list of all hosts, separated by ,} moet vervangen worden door een lijst van de servers, e.a.
```

```
gurus-pgsdb-server1.int.corp.com, gurus-pgsdb-server2.int.corp.com, gurus-pgsdb-server3.int.corp.com
- The certificate files are indeed stored in the respective subdirectory.
```

