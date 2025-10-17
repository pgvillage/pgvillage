# Introduction

Het openssl linux commando kan gebruikt worden voor alle uitvoering van taken mbt certificatane, waaronder:

- Generate new private keys, certificate signing requests, certificates, etc. ([chainsmith](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Chainsmith/WebHome.html) uses openssl)
- Query information about certificates, including lifetime/expiry, subject/CommonName, x509 extensions, etc.
- Verification of the combination of a certificate and private key
- Verification of a certificate chain
- Conversion of private keys

This documentation describes all OpenSSL commands, what they can be used for, and how certain things can be done.

# Commandos'

\# Om te controleren of een private key en een cert bij elkaar horen kunnen de volgende md5 hashes vergeleken worden:

openssl rsa -modulus -noout -in "/data/postgres/data/certs/server.key" \| openssl md5

```markdown
openssl x509 -modulus -noout -in "/data/postgres/data/certs/server.crt" | openssl md5
```

```markdown
# To read the certificate from a .crt file:
```

openssl x509 -text -noout -in /data/postgres/data/certs/server.crt

\# To request a certificate from a web server:

```bash
openssl s_client -showcerts -servername acme-vbepr-v11a.acme.corp.com -connect acme-vbepr-v11a.acme.corp.com:443 < /dev/null
```

\# To request a certificate from a PostgreSQL server:

```markdown
Open a connection to initiate TLS with the PostgreSQL server on `acme-dvppg1db-server1.acme.corp.com` at port `5432`, and display the certificates using OpenSSL.
```

```markdown
# To view the certificate chain that Postgres provides:
```

```markdown
openssl crl2pkcs7 -nocrl -certfile /data/postgres/data/certs/server.crt | openssl pkcs7 -print_certs
```

\# Om te controleren of een certifcaat/chain vertrouwd wordt door een  ander certificaat

openssl verify -CAfile ~postgres/.postgresql/root.crt /data/postgres/data/certs/server.crt

```markdown
# To check if a certificate is trusted by an intermediate and root (both separately, not in PG SBB)
```

```markdown
openssl verify -CAfile ~/postgres/.postgresql/root.crt -untrusted ~/postgres/.postgresql/intermediate.crt /data/postgres/data/certs/server.crt
```

# Troubleshooting

## Certificate expired

Since work is being done with a single mutual TLS (mTLS) chain where all client and server certificates have the same expiry date, the expiry can be checked on one certificate to validate the entire chain.

For querying expiration, the following can be executed:

\[postgres@acme-dvppg1db-server2 ~\]$opensslx509-text-noout-in/data/postgres/data/certs/server.crt\|grep-A2Validity

Validity

```
NotBefore: Oct 10 04:48:08 2022 GMT
```

```
NotAfter: Oct 10 04:48:08 2023 GMT
```

```markdown
In this example, the certificates expire on October 11, 2023 (4:48 GMT is 6:48 CEST)...
```
```

Om te controleren of een certificaat nog geldig is, kan ook het volgende commando worden gebruikt:

```markdown
[me@acme-dvppg1db-server1 ~]$ sudo openssl x509 -checkend $(60 * 60 * 24 * 7) -noout -in ~postgres/.postgresql/postgresql.crt
```

Certificate will not expire

Dit commando kijkt naar expiry in de komende week (3600sec. x 24 uur x 7 dagen)...

If the certificates have expired, a new chain must be created and distributed through this procedure: [Generate and Roll Out New Certificates](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Nieuwe+certificaten+genereren+en+uitrollen/WebHome.html)

## Certificate is not accepted

To be able to accept connections, the software must trust the certificate, which works through the chain of trust:

- The certificate must be trusted by the intermediate certificate
- The intermediate certificate must be trusted by the root certificate
  - There can be multiple intermediates applied, but for the PostgreSQL building block it is not applicable.
- The root certificate must be trusted by the software

2 examples:

- To establish an SSL connection to PostgreSQL, the client must be able to accept the server certificate.
  - Postgres uses a server certificate for this purpose, which identifies itself: `/data/postgres/data/certs/server.crt`
  - The client (for example, `psql`) has the chain to validate the server certificate: `~postgres/.postgresql/root.crt`

**Note**: Actually, the intermediate should be associated with the server certificate and not with the root certificate.
- To accept a client connection:
  - The client identifies itself with a certificate: `~postgres/.postgresql/postgresql.crt`
  - This is validated by PostgreSQL using a chain: `/data/postgres/data/certs/root.crt`

The chain can be validated as follows:

#Verifierenvanhetservercertificaat:

```markdown
[postgres@acme-dvppg1db-server2 ~]$
```

`openssl verify -CAfile ~/postgres/.postgresql/root.crt data/postgres/data/certs/server.crt`

```
/data/postgres/data/certs/server.crt: OK
```

#Verifierenvanhetclientcertificaat:

```markdown
[postgres@acme-dvppg1db-server2 ~] $ openssl verify -CAfile /data/postgres/data/certs/root.crt ~/.postgresql/postgresql.crt
```

`/var/lib/pgsql/.postgresql/postgresql.crt`: OK

Om andere certificaten te valideren moeten de certificaten dus wel bij elkaar gebracht worden.

Copy anything if necessary into the `gurus-dbabh-server1` in a temporary folder.

P.s. certificaten zijn publieke data en niet geheim.

Ze kopieren naar tijdelijke folders is dus ook geen security issue.

## ```markdown

subject and CommonName

````

Ieder certificaat heeft een subject en de Common Name is onderdeel van dat subject.

Especially this Common Name is important because it must match what is attempting to authenticate:

- for server certificates, the Fully Qualified Domain Name (FQDN) of the server
- for client certificates, the name of the PostgreSQL user

The subject (and the Common Name) can be easily verified using an `openssl` command:

```bash
openssl x509 -in certificate.crt -noout -subject
````

```markdown
# Example Server Certificate
```

```
Subject: C=NL, ST=Utrecht, L=Blaricum, O=Nibble IT, OU=PgVillage, CN=localhost
```

```markdown
Subject: C=NL, postalCode=1261 WZ, ST=Utrecht, L=Blaricum, street=Binnendelta 1-u 2, O=Nibble IT, OU=PgVillage, CN=server1.nibble-it.local
```

\# Example Client Certificate

```
Subject: CN=pgfga, O=Nibble-IT, OU=Chainmsith, L=Blaricum, ST=Utrecht, C=NL
```

```markdown
Subject: C=NL, postalCode=1261 WZ, ST=Utrecht, L=Blaricum, street=Binnendelta 1-u 2, O=Nibble-IT, OU=PgVillage, CN=pgfga
```

In the example, it can be seen that:

- the server certificate with Common Name (CN) acme-dvppg1db-server2.acme.corp.com is accepted.
  - The certificate will therefore be accepted when clients connect to this host.
- the client certificate with Common Name (CN) postgres
  - This certificate will therefore be accepted when the client attempts to log in as the postgres user.

## x509 extensions en SAN

x509 is een certificaten standaard en deze heeft Extensions gedefinieerd.

There are 2 important extensions:

### Key Usage

```markdown
JDBC sets very high requirements on client certificates, particularly that the following extensions are enabled:
```

- Digital Signature
- Key Encipherment
- Data Encryption

Chainsmith is zo geconfigureerd dat hij deze extensies ook enabled.

To verify this, the following can be done:

```markdown
[postgres@acme-dvppg1db-server2 ~]$ openssl x509 -text -noout -in data/postgres/data/certs/server.crt | grep -A1 'X509v3 Key Usage:'
```

Note: The command is already in English, so no translation was necessary.

X509v3KeyUsage:

Digital Signature, Key Encipherment, Data Encipherment

### Subject Alternative Name

Since TCP proxies (such as [stolon-proxy](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Stolon/WebHome.html) and [HAProxy](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/HAProxy/WebHome.html)) are also used in the PostgreSQL architecture, it is possible that a client connects to an FQDN different from that of the server they are actually connecting to.

For example, he connects to the VIP (acme-dvppg1 **pr-v** 01p.acme.corp.com) and accesses the primary database server, such as acme-dvppg1 **pr-v** 02p.acme.corp.com, via HAProxy and stolon-proxy.

X.509 has an additional extension called Subject Alternative Names (SAN), which allows for configuring extra hostnames.

These can be requested via:

```markdown
[postgres@acme-dvppg1db-server2 ~]$ openssl x509 -text -noout -in /data/postgres/data/certs/server.crt | grep -A1 'X509v3 Subject Alternative Name:'
```

*Note: The translation task does not apply to shell commands or file paths.*

X509v3 Subject Alternative Name:

DNS: acme-dvppg1db-server2.acme.corp.com, IP Address: 10.0.4.43  
DNS: acme-dvppg1pr-v01p.acme.corp.com, IP Address: 10.0.4.*28  
DNS: acme-dvppg1pr-server1.acme.corp.com, IP Address: 10.0.4.*26  
DNS: acme-dvppg1pr-server2.acme.corp.com, IP Address: 10.0.4.*27  
DNS: acme-dvppg1db-server1.acme.corp.com, IP Address: 10.0.4.42  
DNS: acme-dvppg1db-server3.acme.corp.com, IP Address: 10.0.4.44  
DNS: acme-dvppg1db-server4.acme.corp.com, IP Address: 10.0.4.45

**Note:** In addition to DNS entries, this SAN also has IP entries, but it seems the PostgreSQL client does not handle them well.

---

## Conversie Private Keys

For JDBC, a different format (PKCS12 or PKCS8 DER) must be used.

Voor DBeaver is specifiek PKCS8 DER zonder wachtwoord nodig.

These can be generated with the following commands:

#PKCS#8 PEM Format

---

```markdown
OpenSSL PKCS#8 -topk8 -inform PEM -outform PEM -in cims_rw.key -out cims_rw.pk8.pem -nocrypt
```

# PKCS8 DER Format (Suitable for JDBC including DBeaver)

---

```shell
openssl pkcs8 -topk8 -inform PEM -outform DER -in cims_rw.key -out cims_rw.pk8 -nocrypt
```

# PKCS12 Format (Also Suitable for JDBC, Always with Password)

---

```markdown
openssl pkcs12 -export -nocerts -inkey cims_rw.key -out cims_rw.p12
```

By the way, a password must sometimes be set for the keys as well:

#PKCS#8 PEM Format

---

```markdown
openssl pkcs8 -topk8 -inform PEM -outform PEM -in cims_rw.key -out cims_rw.pk8.pem
```

```markdown
# PKCS8 DER Format (Suitable for JDBC Including DBeaver)
```

```markdown
openssl pkcs8 -topk8 -inform PEM -outform DER -in cims_rw.key -out cims_rw.pk8
```

```markdown
# PKCS12 Format (Suitable for JDBC, Always with Password So Same Command)
```

```markdown
openssl pkcs12 -export -nokeys -in cims_rw.pem -out cims_rw.p12
```

[Chainsmith](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Chainsmith/WebHome.html) generates automatically the standard PEM and PKCS8 format keys.

These can be found in the temporary folder (or the GPG archive).

Example for client certificates for the Postgres user:

- `./tls/int_client/private/postgres.key.pem`

PEM format  
- `./tls/int_client/private/postgres.key.pk8`  

*Note: The file path appears to be in English.*

PKCS#8 format (ASCII)  
- `./tls/int_client/private/postgres.key.der`

PK8 format (DATA)

