# Chainsmith

Chainsmith is a community tool that can be configured with a simple YAML file to generate certificate chains.

- Community repository: [https://github.com/pgvillage-tools/chainsmith](https://github.com/pgvillage-tools/chainsmith)

- Python module on PyPI: [https://pypi.org/search/?q=chainsmith](https://pypi.org/search/?q=chainsmith)

---

## Requirements and Dependencies

Within the PostgreSQL deployment, we use Chainsmith as follows:

- We install chainsmith on the management server (and updates).
- We maintain chainsmith config files in the ansible-postgres repository.
  - See [From server to running database](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Van+server+naar+draaiende+database/WebHome.html) for more information.
- We run chainsmith and store the certificates in Ansible Vault.
  - See [From server to running database](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Van+server+naar+draaiende+database/WebHome.html) for more information.
- We use the certificates.
- When monitoring indicates that the certificates are about to expire, we discard the current certificates and deploy new ones.

Further supplies:

- A Linux server with:
  - A recent version of Python
  - A recent version of OpenSSL

---

## Installation and Upgrade 

To install or upgrade Chainsmith on the management server:

```bash
sudo pip3 install --upgrade chainsmith
```

## Use

For using Chainsmith, three things are needed:

- **Bash script** (see [the script in GitLab](https://gitlab.int.corp.com/gurus-db-team/ansible-postgres/-/blob/dev/bin/chainsmith.sh)). 

The bash script supports the following parameter settings:
  - `CHAINSMITH\_DONTGPG`        - Determines whether or not to perform gpg encryption
  - `CHAINSMITH\_DONTSHRED `     - Determines whether the created files are deleted with shred
- **Chainsmith** itself (see installation above)
- **Configuration file** (per cluster). Examples of the configuration file:
  - in GitLab: [https://gitlab.int.corp.com/gurus-db-team/ansible-postgres/-/tree/dev/config](https://gitlab.int.corp.com/gurus-db-team/ansible-postgres/-/tree/dev/config)
  - In the appendices

---

### Bash script

The script performs the following actions:

1. **Invokes Chainsmith properly.**  
   Output is stored temporarily under `/tmp`.
2. **Encrypts and stores output in the Ansible inventory:**
   - Certificates: `environments/[clustername]/group_vars/all/certs.yml`
   - Private keys: `environments/[clustername]/group_vars/all/certsvault.yml`  
     (An Ansible Vault file encrypted with the standard vault password)
3. **To rerun the script**, delete the old files first:
   ```bash
   CLUSTERNAME=<clustername>
   rm -f ./environments/${CLUSTERNAME}/group_vars/all/cert{s,vault}.yml
   ```

- Temporary files are stored encrypted (if necessary for issuing new client certificates).
  - This can be disabled by using the option `CHAINSMITH_DONTGPG=yes`.
- The temporary data is cleaned up via the shred command.
  - This can be disabled by using the option `CHAINSMITH_DONTSHRED=yes`.

**Warning**: The script uses GPG (for the Ansible vault password and also to encrypt the chain for storage).

To ensure GPG runs properly in scripts, configure the terminal as follows:

```bash
export GPG_TTY=$(tty)
```

See for more information about the execution:

- the documentation on [From server to running database](https://wiki.corp.com/xwiki/bin/view/Infrastructuur/Team%3A%20DBA/Werkinstrukties/Postgres/Bouwsteen/Van%20server%20naar%20draaiende%20database/)
- the attachments of this page

## Attachments

### Example configuration file

Content of this file:

---

subject:

```bash
C: NL/postalCode=3721MA
Utrecht
Bilthoven/Streets = Antonie van Leeuwenhoekln 9
O:  Nibble IT
#PostgreSQL Building Block
CN: postgres

tmpdir: /tmp/certs/postgres

intermediates:
  - name: server
    keyUsages:
      - keyEncipherment
      - dataEncipherment
      - digitalSignature
    extendedKeyUsages:
      - serverAuth

servers:

# You can set servers directly

acme-dvppg2db-server1.acme.corp.com:
\- 10.0.4.*31

acme-dvppg2db-server2.acme.corp.com
\- 10.0.4.*32

acme-dvppg2db-server3.acme.corp.com
\- 10.0.4.*33

acme-dvppg2pr-v01a.acme.corp.com
\- 10.0.4.*37

acme-dvppg2pr-server1.acme.corp.com
\- 10.0.4.*35

acme-dvppg2pr-server2.acme.corp.com
\- 10.0.4.*36

acme-dvppg2db-server2.acme.corp.com:
\- 10.0.4.*32

acme-dvppg2db-server1.acme.corp.com
\- 10.0.4.*31

acme-dvppg2db-server3.acme.corp.com
\- 10.0.4.*33

acme-dvppg2pr-v01a.acme.corp.com
\- 10.0.4.*37

acme-dvppg2pr-server1.acme.corp.com
\- 10.0.4.*35

acme-dvppg2pr-server2.acme.corp.com
\- 10.0.4.*36

acme-dvppg2db-server3.acme.corp.com:
\- 10.0.4.*33

acme-dvppg2db-server1.acme.corp.com
\- 10.0.4.*31

acme-dvppg2db-server2.acme.corp.com
\- 10.0.4.*32

acme-dvppg2pr-v01a.acme.corp.com
\- 10.0.4.*37

acme-dvppg2pr-server1.acme.corp.com
\- 10.0.4.*35

acme-dvppg2pr-server2.acme.corp.com
\- 10.0.4.*36

acme-dvppg2bc-server1.acme.corp.com:
\- 10.0.4.*30


- name: client
keyUsages:
  - keyEncipherment
  - dataEncipherment
  - digitalSignature
extendedKeyUsages:
  - `clientAuth`
clients:
  - postgres
  - covid_api
  - soa_suite_api
  - vcapi_admin
  - av checker
  - pgroute66
  - pagea
  - pgquartz
```

Basic setup includes a cluster with three database servers, two proxies, and a VIP (V01). The BC is a backup server.

### Example Execution

```bash
$ pwd

/home/me/git/ansible-postgres

$ set | grep CHAIN

$ bin/chainsmith.sh vbe2_a
```

Temporary data in /tmp/tmp.o9zP5pXYhu

Encryption successful

**Creating a tar file with all Certificate Signing Requests: /home/me/git/ansible-postgres/tmp/vbe2_a.csr.tar.gz**

```bash
./tls/int_server/csr/acme-dvppg2db-server1.acme.corp.com.csr

./tls/int_server/csr/acme-dvppg2db-server2.acme.corp.com.csr

./tls/int_server/csr/acme-dvppg2db-server3.acme.corp.com.csr

./tls/int_server/csr/acme-dvppg2bc-server1.acme.corp.com.csr

./tls/int_client/csr/postgres.csr

TLS/INT_CLIENT/CSR/COVID_API.CSR

./tls/int_client/csr/soa_suite_api.csr

./tls/int_client/csr/vcapi_admin.csr

./tls/int_client/csr/avchecker.csr

./tls/int_client/csr/pgroute66.csr

./tls/int_client/csr/pgfga.csr

./tls/int_client/csr/pgquartz.csr
```

**Creating gpg-tarred file with all client certificates and keys: /home/me/git/ansible-postgres/tmp/vbe2_a.clientcerts.tar.gpg**

```
./tls/certs/cacert.pem

./tls/certs/ca-chain-bundle.cert.pem

./tls/newcerts/01.pem

./tls/newcerts/02.pem

./tls/private/cakey.pem

/tls/int_server/certs/cacert.pem

./tls/int_server/certs/ca-chain-bundle.cert.pem

./tls/int_server/certs/acme-dvppg2db-server1.acme.corp.com.pem

./tls/int_server/certs/acme-dvppg2db-server2.acme.corp.com.pem

./tls/int_server/certs/acme-dvppg2db-server3.acme.corp.com.pem

./tls/int_server/certs/acme-dvppg2bc-server1.acme.corp.com.pem

./tls/int_server/csr/intermediate.csr.pem

./tls/int_server/private/cakey.pem

./tls/int_server/private/acme-dvppg2db-server1.acme.corp.com.key.pem

./tls/int_server/private/acme-dvppg2db-server1.acme.corp.com.key.pk8

./tls/int_server/private/acme-dvppg2db-server1.acme.corp.com.key.der

./tls/int_server/private/acme-dvppg2db-server2.acme.corp.com.key.pem

./tls/int_server/private/acme-dvppg2db-server2.acme.corp.com.key.pk8

./tls/int_server/private/acme-dvppg2db-server2.acme.corp.com.key.der

./tls/int_server/private/acme-dvppg2db-server3.acme.corp.com.key.pem

./tls/int_server/private/acme-dvppg2db-server3.acme.corp.com.key.pk8

./tls/int_server/private/acme-dvppg2db-server3.acme.corp.com.key.der

./tls/int_server/private/acme-dvppg2bc-server1.acme.corp.com.key.pem

./tls/int_server/private/acme-dvppg2bc-server1.acme.corp.com.key.pk8

./tls/int_server/private/acme-dvppg2bc-server1.acme.corp.com.key.der

./tls/int_client/certs/cacert.pem

./tls/int_client/certs/ca-chain-bundle.cert.pem

./tls/int_client/certs/postgres.pem

./tls/int_client/certs/covid_api.pem

./tls/int_client/certs/soa_suite_api.pem

./tls/int_client/certs/vcapi_admin.pem

./tls/int_client/certs/avchecker.pem

./tls/int_client/certs/pgroute66.pem

./tls/int_client/certs/pgfga.pem

./tls/int_client/certs/pgquartz.pem

./tls/int_client/csr/intermediate.csr.pem

./tls/int_client/private/cakey.pem

./tls/int_client/private/postgres.key.pem

./tls/int_client/private/postgres.key.pk8

./tls/int_client/private/postgres.key.der

./tls/int_client/private/covid_api.key.pem

./tls/int_client/private/covid_api.key.pk8

./tls/int_client/private/covid_api.key.der

./tls/int_client/private/soa_suite_api.key.pem

./tls/int_client/private/soa_suite_api.key.pk8

./tls/int_client/private/soa_suite_api.key.der

./tls/int_client/private/vcapi_admin.key.pem

./tls/int_client/private/vcapi_admin.key.pk8

./tls/int_client/private/vcapi_admin.key.der

./tls/int_client/private/avchecker.key.pem

./tls/int_client/private/avchecker.key.pk8

./tls/int_client/private/avchecker.key.der

./tls/int_client/private/pgroute66.key.pem

./tls/int_client/private/pgroute66.key.pk8

./tls/int_client/private/pgroute66.key.der

./tls/int_client/private/pgfga.key.pem

./tls/int_client/private/pgfga.key.pk8

./tls/int_client/private/pgfga.key.der

./tls/int_client/private/pgquartz.key.pem

./tls/int_client/private/pgquartz.key.pk8

./tls/int_client/private/pgquartz.key.der

Cleaning temp files (scrambling and then removing)

Finished successfully

Created files:

Creating tar file with all Certificate Signing Requests: /home/me/git/ansible-postgres/tmp/vbe2_a.csr.tar.gz

Creating GPG-encrypted tar file containing all client certificates and keys: /home/me/git/ansible-postgres/tmp/vbe2_a.clientcerts.tar.gpg
```

!!! note

    In the procedure, you will be asked for the 'own' passphrase and also the passphrase for the GPG file, which is again needed to decrypt the file!

### Example decryption of temporary files

```bash
[me@gurus-dbabh-server1 tmp]$ ll *.gpg

-rw-rw-r-- 1 me me 126158 Aug 12 14:53 vbe2_a.clientcerts.tar.gpg

$ gpg -d vbe2_a.clientcerts.tar.gpg > vbe2_a.clientcerts.tar.gz

gpg: AES-encrypted data

gpg: encrypted with 1 passphrase

$ gunzip vbe2_a.clientcerts.tar.gz

`tar -xvf vbe2_a.clientcerts.tar`

./tls/certs/cacert.pem

./tls/certs/ca-chain-bundle.cert.pem

./tls/newcerts/01.pem

./tls/newcerts/02.pem

./tls/private/cakey.pem

./tls/int_server/certs/cacert.pem

./tls/int_server/certs/ca-chain-bundle.cert.pem

./tls/int_server/certs/acme-dvppg2db-server1.acme.corp.com.pem

./tls/int_server/certs/acme-dvppg2db-server2.acme.corp.com.pem

./tls/int_server/certs/acme-dvppg2db-server3.acme.corp.com.pem

./tls/int_server/certs/acme-dvppg2bc-server1.acme.corp.com.pem

./tls/int_server/csr/intermediate.csr.pem

./tls/int_server/private/cakey.pem

./tls/int_server/private/acme-dvppg2db-server1.rivp.corp.com.key.pem

./tls/int_server/private/acme-dvppg2db-server1.acme.corp.com.key.pk8

./tls/int_server/private/acme-dvppg2db-server1.acme.corp.com.key.der

./tls/int_server/private/acme-dvppg2db-server2.acme.corp.com.key.pem

./tls/int_server/private/acme-dvppg2db-server2.acme.corp.com.key.pk8

./tls/int_server/private/acme-dvppg2db-server2.acme.corp.com.key.der

./tls/int_server/private/acme-dvppg2db-server3.acme.corp.com.key.pem

./tls/int_server/private/acme-dvppg2db-server3.acme.corp.com.key.pk8

./tls/int_server/private/acme-dvppg2db-server3.acme.corp.com.key.der

./tls/int_server/private/acme-dvppg2bc-server1.acme.corp.com.key.pem

./tls/int_server/private/acme-dvppg2bc-server1.acme.corp.com.key.pk8

./tls/int_server/private/acme-dvppg2bc-server1.acme.corp.com.key.der

./tls/int_client/certs/cacert.pem

./tls/int_client/certs/ca-chain-bundle.cert.pem

./tls/int_client/certs/postgres.pem

./tls/int_client/certs/covid_api.pem

./tls/int_client/certs/soa_suite_api.pem

./tls/int_client/certs/vcapi_admin.pem

./tls/int_client/certs/avchecker.pem

./tls/int_client/certs/pgroute66.pem

./tls/int_client/certs/pgfga.pem

./tls/int_client/certs/pgquartz.pem

./tls/int_client/csr/intermediate.csr.pem

./tls/int_client/private/cakey.pem

./tls/int_client/private/postgres.key.pem

./tls/int_client/private/postgres.key.pk8

./tls/int_client/private/postgres.key.der

./tls/int_client/private/covid_api.key.pem

./tls/int_client/private/covid_api.key.pk8

./tls/int_client/private/covid_api.key.der

./tls/int_client/private/soa_suite_api.key.pem

./tls/int_client/private/soa_suite_api.key.pk8

./tls/int_client/private/soa_suite_api.key.der

./tls/int_client/private/vcapi_admin.key.pem

./tls/int_client/private/vcapi_admin.key.pk8

./tls/int_client/private/vcapi_admin.key.der

./tls/int_client/private/avchecker.key.pem

./tls/int_client/private/avchecker.key.pk8

./tls/int_client/private/avchecker.key.der

./tls/int_client/private/pgroute66.key.pem

./tls/int_client/private/pgroute66.key.pk8

./tls/int_client/private/pgroute66.key.der

./tls/int_client/private/pgfga.key.pem

./tls/int_client/private/pgfga.key.pk8

./tls/int_client/private/pgfga.key.der

./tls/int_client/private/pgquartz.key.pem

./tls/int_client/private/pgquartz.key.pk8

./tls/int_client/private/pgquartz.key.der

# Example of compiling client certificate bundles:

tar -cv ./tls/int_server/certs/ca-chain-bundle.cert.pem ./tls/int_client/certs/covid_api.pem ./tls/int_client/certs/vcapi_admin.pem ./tls/int_client/certs/soa_suite_api.pem ./tls/int_client/private/covid_api.key.pem ./tls/int_client/private/covid_api.key.pk8 ./tls/int_client/private/covid_api.key.der ./tls/int_client/private/soa_suite_api.key.pem ./tls/int_client/private/soa_suite_api.key.pk8 ./tls/int_client/private/soa_suite_api.key.der ./tls/int_client/private/vcapi_admin.key.pem ./tls/int_client/private/vcapi_admin.key.pk8 ./tls/int_client/private/vcapi_admin.key.der | gzip | gpg -c > ~/covid_api_vbe2_a.gpg

./tls/int_server/certs/ca-chain-bundle.cert.pem

./tls/int_client/certs/covid_api.pem

./tls/int_client/certs/vcapi_admin.pem

./tls/int_client/certs/soa_suite_api.pem

.tls/int_client/private/covid_api.key.pem

./tls/int_client/private/covid_api.key.pk8

./tls/int_client/private/covid_api.key.der

./tls/int_client/private/soa_suite_api.key.pem

./tls/int_client/private/soa_suite_api.key.pk8

./tls/int_client/private/soa_suite_api.key.der

./tls/int_client/private/vcapi_admin.key.pem

./tls/int_client/private/vcapi_admin.key.pk8

./tls/int_client/private/vcapi_admin.key.der

# Basically identical, but now made more readable for a single account:

tar -cv ./tls/int_server/certs/ca-chain-bundle.cert.pem

./tls/int_client/certs/aerius.pem

./tls/int_client/private/aerius.key.pem

./tls/int_client/private/aerius.key.pk8

`cat tls/int_client/private/aerius.key.der | gzip | gpg -c > ~/Certificates_aerius_P.gpg`

Exactly the same, but easier (command on one line)

USER=vens\_java

ENV=vbe2_p

tar -cv ./tls/int_server/certs/ca-chain-bundle.cert.pem ./tls/int_client/certs/$USER.pem ./tls/int_client/private/$USER.key.pem  ./tls/int_client/private/$USER.key.pk8 ./tls/int_client/private/$USER.key.der | gzip | gpg -c >~/Certs_${USER}_${ENV}.gpg
```

A passphrase is requested for use. Share it with the requester so they can unpack the bundle.

### Example of using the bundle

#### psql

```bash
$ psql "host=acme-dvppg2pr-v01t.rivp.corp.com sslmode=require sslrootcert=./tls/int_server/certs/ca-chain-bundle.cert.pem sslcert=./tls/int_client/certs/covid_api.pem sslkey=./tls/int_client/private/covid_api.key.pem port=5432 user=covid_api dbname=vcapi"

psql (12.11)

SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)

Type "help" for help.

vcapi => \c
```

SSL connection (protocol: TLSv1.3, cipher: TLS\_AES\_256\_GCM\_SHA384, bits: 256, compression: off)

You are now connected to database "vcapi" as user "covid_api".

vcapi=>

#### DBeaver

DBeaver on the Windows Management Server, Gurus-MANDB-W01P
