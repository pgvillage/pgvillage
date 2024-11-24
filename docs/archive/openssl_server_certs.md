**Note:** For automation and reproducibility, [ChainSmith](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Chainsmith/WebHome.html) is used.

# Introduction

Binnen deze bouwsteen worden server certificaten gebruikt voor identificatie van postgres database servers.

Dit heeft als voordeel dat de client met abslute zekerheid weet dat de communicatie direct et de database server plaats vindt.

Furthermore, the traffic is encrypted in such a way that only the client and server know about the communication (TLS in transit).

The PostgreSQL client uses a root certificate to verify the trustworthiness of the PostgreSQL database server.

# Requirements

To be able to authenticate with client certificates, the following is needed:

- hostssl in the hba file
- ssl=on within postgres
- a valid server certificate
  - not yet expired
  - matching the server FQDN
- a root certificate on the client that trusts the server certificate

# How it works

## Why SAN Certificates?

For the FrontEnd, a SAN certificate is not required, but it's still nice to have one.

Het primaire verkeer komt binnen op de VIP en derhalve moet de CN van het certificaat overeenkomen met de CN van de VIP.

The VIP can be linked to two hosts and on both hosts, HAProxy ensures that the traffic is balanced across two other hosts.

Since the API can be called via the VIP, but also on the hostnames of the 4 hosts, the certificate should actually have all 4 hosts as alternate names.

For Postgres certificates, there are more types of traffic and also traffic directed towards hosts. In fact:

- Most of the traffic comes in on the VIP.
- However, there is also replication traffic to the master and to the cascading standby.
- There is also traffic from PgBouncer (on the proxies) to the master database server.
- Connecting to the VIP means that you are transparently connected at the TCP level to:
  - Postgres on the RW part (5432)
  - Postgres on the RO part (5433)
  - PgBouncer on the RO part (6433)

This means, for example, that a connection on VIP:5432 sees the same certificate as a replication connection on MASTER:5432 (and those are different hostnames).

It is possible to make (part of) the traffic accept a certificate with an incorrect CN, but it's better to use a SAN certificate.  
```

### For which hosts?

The following certificates need to be applied for:

---

1. A certificate for PostgreSQL traffic (backend) for the following CN/Alternatives:
```

De huidige chainsmith configuratie genereert aparte certificaten voor iedere host.

This can be with Ansible inventory adjustments 1 certificate  
   - VIP (CN)  
   - Backend Proxy 1 and 2 (Alternative)  
   - All postgres servers (Alternative)  

2. A certificate for the backup server. This traffic is actually completely separated, but the existing automation for certificate chains is reused to also create this chain.

### Hoe de CSR aanmaken

> **Note:** This is reference documentation. Use [Documentatie uitrollen nieuwe certificaten](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Nieuwe+certificaten+genereren+en+uitrollen/WebHome.html)

---

As a basis, the procedure used is found on [this link](https://support.citrix.com/article/CTX227983).

```
1: Create a configuration file for OpenSSL. Save this as req.conf.
```

Voorbeelden in het volgende hoofdstuk

2: Generate the CSR and the private key:

\# Generate

```markdown
openssl req -new -out company_san.csr -newkey rsa:4096 -nodes -sha256 -keyout company_san.key.temp -config req.conf
```

# Convert the key into PKCS#1

```markdown
openssl rsa -in company_san.key.temp -out company_san.key
```

\# Zet de CSR in leesbaar formaat in een file ernaast

```markdown
openssl req -text -noout -verify -in company_san.csr > company_san.csr.txt
```

Or a simple little script:

```markdown
# In the Folder with the Configuration Files:
```

```markdown
# cat generate.sh
```

#!/bin/bash

```markdown
ENDPOINT=${1:-unknown}
```

```markdown
`-f ${ENDPOINT}.conf || echo "${ENDPOINT}.conf does not exist"; exit 1`
```

```bash
openssl req -new -out ${ENDPOINT}.csr -newkey rsa:4096 -nodes -sha256 -keyout ${ENDPOINT}.key.temp -config ${ENDPOINT}.conf
```

```bash
openssl req -text -noout -verify -in ${ENDPOINT}.csr > ${ENDPOINT}.csr.txt
```

```bash
openssl rsa -in ${ENDPOINT}.key.temp -out ${ENDPOINT}.pem
```

```bash
sed 's/^/        /'${ENDPOINT}.pem
```

\# Call:

./generate.sh abackend

./generate.sh afrontend

./generate.sh awitness

```
3: Store the private key in Ansible Vault
```

- Located in `vault/certs/`
- Most are symlinks.
- You need the `acme-vbepr-v*.acme.corp.com.yml` and the `acme-vberm-l01*.acme.corp.com.yml`.
- Open with `ansible-vault edit [file]`
- Pay attention to the alignment (2 spaces) under `private_ssl_key`.

```
4: Create a JIRA ticket with the details:
```

- With label BI-CIF-SERVICES
- With the CSR (company_san.csr and company_san.csr.txt)
- With a description of what the CSR is for

### Deploy Certificates

```
Note: This is reference documentation. Use [Chainsmith](../../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/Chainsmith/WebHome.html)...
```

```markdown
1. Save the certificates in Ansible Vault as well  
   - Certificates themselves are located in `vault/certs/`  
   - Most files there are symlinks.  
   - You need the `acme-vbepr-v*.acme.corp.com.yml` and `acme-vberm-l01*.acme.corp.com.yml`  
   - Open with `ansible-vault edit [file]`  
   - Pay attention to the alignment (2 spaces) under `public_ssl_key`.  
   - Enter the certificate, followed by the certificates from the chain. The root certificate at the bottom can be omitted.  

2. If necessary, also update the root certificate  
   - Found in `"environments/000_cross_env_vars"` as key `postgres_root_cert`  
   - It is placed correctly for all PostgreSQL clients  
   - This should contain the root certificate of the chain. This would be the lowest one from the chain (omitted at point 1).  

3. Deploy via Ansible. Steps: pgbouncer, postgres, and nginx.  
   - Everything should be automatically reloaded if done correctly, but manual reloading may still be necessary.
```

### Tips and Tricks

---

See [OpenSSL](../../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/OpenSSL/WebHome.html) for commands for verification.

### Examples `rec.conf`

```markdown
Warning: This is reference documentation. Use [Chainsmith](../../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/Chainsmith/WebHome.html)...
```
```

#### BackEnd in A

\[req\]

`distinguished_name = req_distinguished_name`

---

```markdown
req_extensions=v3_req
```

no prompt

```markdown
[request distinguished name]
```

C=NL

UTRECHT

`L = Bilthoven`

= National Institute for Public Health and the Environment (Acme)

```markdown
CN=acme-vbepr-v01a.acme.corp.com
```

`[v3_req]`

```
keyUsage = keyEncipherment, dataEncipherment
```

```
extendedKeyUsage=serverAuth
```

```
subjectAltName = @alt_names
```

\[alt\_names\]

```
DNS.1=acme-vbepr-server1.acme.corp.com
```

DNS.2=acme-vbepr-server2.acme.corp.com

```
DNS.3=acme-vbedb-server1.rivv.corp.com
```

```
DNS.4=acme-vbedb-server2.acme.corp.com
```

DNS.5=acme-vbedb-server3.acme.corp.com

```
DNS.6=acme-vbedb-server4.acme.corp.com
```

```
DNS.7= acme-vbedb-server5.acme.corp.com
```

```
DNS.8=acme-vbedb-server6.rivv.corp.com
```

