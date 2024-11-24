# Introduction

Once the servers are requested ([server request](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Van+database+aanvraag+naar+server+aanvraag/WebHome.html)), delivered, and set up ([set up cluster](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Van+server+naar+draaiende+database/WebHome.html)), a message must be sent back to the requester.

Deze instructie beschrijft de vorm en inhoud van dit bericht.

# Dependencies

```markdown
- [server request](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Van+database+aanvraag+naar+server+aanvraag/WebHome.html)
- [set up cluster](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Van+server+naar+draaiende+database/WebHome.html)
- [client connection information](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Clients/WebHome.html)
- [Client certificates](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/Client+certificaten/WebHome.html)
```

# Instruction

1: collect the client certificates and the server root certificate:
-

The certificates are in the inventory:

ENV=poc

cat environments/$ENV/group\_vars/all/certs.yml

Kopieer het certificaat in de bundel certs.client.\[user\] (bijvoorbeeld certs.client.minous), sla het op in een bestand in de tmp directory en haal de spaties aan het begin weg:

USR=minous

```bash
TMPDIR=$(mktemp -d)
```

open `vim` and edit `$TMPDIR/$USR.crt`

#paste the data and save with `:x`

```markdown
sed -i 's/^ \*//' $TMPDIR/$USR.crt
```

Copy the server root certificate into the `certs.server.chain` bundle, save it to a file in the same `tmp` directory and also remove any leading spaces here:

```bash
cat certs.server.chain | tr -d ' ' > tmp/server_root_cert.pem
```
```

```
vim /var/tmp/root.crt
```

#paste the data and save with :x

```markdown
sed -i 's/^ \*//' $TMPDIR/root.crt
```

The private key of the client certificate is stored in the ansible-vault:

---

ENV=poc

```markdown
ansible-vault decrypt --output=- environments/$ENV/group_vars/all/certsvault.yml
```

Copy the certificate into the bundle `private_keys.client.[user]` (for example, `private_keys.client.minous`), save it to a file in the `tmp` directory and remove any spaces at the beginning:
-

USR=minous

#```shell
TMPDIR=$(mktemp -d)
```

```markdown
edit $TMPDIR/$USR.key
```

#paste the data and save with `:x`

```markdown
sed -i 's/^ \*//' $TMPDIR/$USR.key
```

Create a `$TMPDIR/pg_service.conf` file. For the content, see [pg_service](../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/Antwoord+aan+de+aanvrager/pg_service/WebHome.html).

Create a `$TMPDIR/jdbc.txt` file. For the content, see [jdbc url](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Antwoord+aan+de+aanvrager/jdbc+url/WebHome.html).

```markdown
Create a `$TMPDIR/openssl.txt` file. For the content, refer to the commands in [openssl commandos](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/openssl/WebHome.html).
```

You now have a folder with the following files:

- `{user}.crt`
- `{user}.key`
- `root.crt`
- `pg_service.conf`
- `jdbc.txt`
- `openssl.txt`

This folder needs to be packed, encrypted (with a key that only you and the recipient know), and sent via email.

#USR=minous

#ENV=poc

#`TMPDIR=$(mktemp -d)`

cd

```markdown
tar -cv "$TMPDIR" | gzip | gpg -c > ~/"$USR_$ENV.gpg"
```

The final file in the home directory must be downloaded to the workplace and sent via email to the user with the following cover letter:
-

Dear Mr./Ms. {applicant},

The requested database has been made available on the database cluster {VIP FQDN or DB Servers}.

Attached is a GPG encrypted tar file containing all the necessary files:

---

- the client certificate, the corresponding key, and a root.cert

---

\- an example `pg_service.conf` file

- an example file with JDBC URLs

- a text file with OpenSSL commands

Dit zou u op weg moeten helpen om succesvol een connectie te kunnen maken met de aangevraagde database.

If you need further assistance, please do let us know.

---

With kind regards,

En dan natuurlijk een eigen EMail handtekening.

Send the email to the applicant and ask for a mobile number to send the password of the GPG encrypted attachment.

