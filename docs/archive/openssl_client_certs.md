> Note: For automation and reproducibility, [ChainSmith](https://wiki.corp.com/xwiki/bin/view/Infrastructuur/Team%3A%20DBA/Werkinstrukties/Postgres/Bouwsteen/Chainsmith/) is used. and [Documentation Generate and Roll Out New Certificates](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Nieuwe+certificaten+genereren+en+uitrollen/WebHome.html)

# Introduction

Binnen deze bouwsteen worden client certificaten gebruikt voor authenticatie van postgres users.

Client certificaat authenticatie heeft als voordeel dat het certificaat en de key niet op de PostgreSQL database servers bekend hoeft te zijn.

PostgreSQL gebruikt een root certificaat om de betrouwbaarheid van het client certificaat te controleren.

Dat kan (als het intermediate met de sleutel bewaard is) ook achteraf nieuwe certificaten worden uitgegeven.

Further, each client certificate is issued for a specific user, making it harder to remember and copy, and requiring server TLS.

Het is dus een veiligere oplossing. Het vereist echter ook een hoger kennis niveau, met name in beheer.

# Benodigdheden

Om met client certificaten te kunnen authentiseren is het volgende nodig:

- A TLS connection. That means:
  - `hostssl` in the HBA file
  - `ssl=on` within PostgreSQL
  - a valid server certificate
    - not expired
    - corresponding to the server FQDN
  - a root certificate on the client that trusts the server certificate
- A valid client certificate
  - not expired
  - corresponding to the user who is logging in
- A root certificate on the PostgreSQL database server that trusts the client certificate
- A rule in the PostgreSQL HBA file that prescribes certificates as an authentication method for this communication
  - Managed with Ansible: `environments/[ENVIRONMENT]/group_vars/all/generic.yml`
  - Example:

**hostssl** cmdbvm cmdb 10.0.6.188/32 **cert**

**Note:** Both `hostssl` and `cert` are required.

- The rule must be the first one that applies (not under another rule with a different method).

# Reference material

---

> **Note:** This is reference documentation. Use [Chainsmith](/xwiki/bin/get/Infrastructuur/Team%3A%20DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/Server%20certificaten/?sheet=CKEditor.ResourceDispatcher&outputSyntax=plain&language=en&type=doc&reference=Infrastructuur.Team%5C%3A+DBA.Werkinstrukties.Postgres.Bouwsteen.Chainsmith.WebHome&typed=true) and the [generate and roll out new certificates documentation](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Nieuwe+certificaten+genereren+en+uitrollen/WebHome.html)

Voor het genereren van client certificaten is alleen een recente versie van openssl nodig.

Verder beschrijft deze WI alle stappen die nodig zijn voor het genereren van een nieuwe chain.

The WI is inspired by, among other things:

```markdown
[https://www.makethenmakeinstall.com/2014/05/ssl-client-authentication-step-by-step/](https://www.makethenmakeinstall.com/2014/05/ssl-client-authentication-step-by-step/)
```

## Aanmaken CA

certificaten worden altijd ondertekend door een ander certificaat.

Voor server certificaten kan dit extern signed worden met een lange chain van intermediate certs.

En in andere situaties kan een certificaat self signed zijn.

Voor client certificaten is het nodig dat er een CA is.

And for our application, an intermediate actually has little added value.

We gaan daarom een CA maken die direct client certificaten kan ondertekenen.

On the system with OpenSSL:

\# Go to a new folder. Here come the temporary certificates and private keys:

cd$(mktemp -d)

# Copy `/etc/pki/tls/openssl.cnf` into this folder:

---

cp /etc/pki/tls/openssl.cnf ./ca.cnf

Then adjust the following in the locally copied `ca.cnf`:

```markdown
[Your specific changes here]
```

- In the chapter \[ req \], it must:
  - remove an existing option: `attributes = req_attributes`
  - add a new option: `prompt = no`
- The entire existing content in the chapter \[ req\_distinguished\_name \] can be replaced with:

```markdown
CN = **[REPLACED BY VIP HOSTNAME FOR API OR POSTGRES]**
```

C = NL

UT = Utrecht

```
L = Bilthoven
```

```markdown
=  National Institute for Public Health and the Environment (Acme)
- In the chapter `[usr_cert]`, `nsCertType = client, email` must be set
```

Example diff:

diff /etc/pki/tls/openssl.cnf ca.cnf

110d109

< attributes  = req\_attributes

111a111

```
> prompt = no
```

129,156c129,133

```markdown
countryName = Landnaam (2 letters code)
```

```markdown
<countryName_default = XX>
```

```markdown
< countryName_min = 2 >
```

```markdown
< countryName_max     = 2 >
```

<

```markdown
<stateOrProvinceName> = State or Province Name (full name)
```

```markdown
# stateOrProvinceName_default = Default Province
```

<

< localityName   = Locality Name (eg, city)

```markdown
<localityName_default = Default City>
```

<

```markdown
< 0.organizationName = Organization Name (e.g., company)
```

```markdown
< 0.organizationName_default = Default Company Ltd>
```

<

```markdown
# We can do this, but it's not usually necessary :-)
```

```markdown
#1.organizationName = Second Organization Name (e.g., company)
```

```markdown
#1.organizationName_default = World Wide Web Pty Ltd
```

<

```
organizationalUnitName = Organizational Unit Name (e.g., section)
```

```markdown
# organizationalUnitName_default =
```

<

```markdown
commonName = Common Name (e.g., your name or your server's hostname)
```

```markdown
< commonName_max   = 64 >
```

<

```
emailAddress = Email Address
```

```markdown
emailAddress_max = 64
```

<

```markdown
# SET-ex3 = SET extension number 3
```

\-\-\-

```
> CN = acme-vbepr-v01a.acme.corp.com
```

```
> C = NL
```

```markdown
ST = Utrecht
```

> L = Bilthoven

> O = National Institute for Public Health and the Environment (Acme)

184c161

```markdown
# nsCertType = client, email
```

\-\-\-

```markdown
nsCertType = client, email
```

Then the root certificate can be created:

openssl req -newkey rsa:4096 -nodes -keyform PEM -keyout ca.pem -x509 -days 3650 -outform PEM -out ca.cer -config ca.cnf

Generating a 4096 bit RSA private key

.........................................................++

.................................++

```markdown
generating a new private key and saving it to 'ca.pem'
```

\-\-\---

## Aanmaken van een client certificaat

Take care:

```markdown
- For Postgres: Create a client certificate for every user who logs in with client certificates. Use the username as CN in the config file:
  - postgres
  - avchecker
  - pgquartz
  - pgfga
```

For each client, a separate request must be made. Example for `pgrep_user`:

# Copy the config and adjust CN = ... to the username

```markdown
sed 's/CN \*=.* /CN = pgquartz/ ' ca.cnf > pgquartz.cnf
```

\# Generate a new private key:

openssl genrsa -out pgquartz.key 4096

# Generate a New CSR

```markdown
openssl req -new -key pgquartz.key -out pgquartz.req -config pgquartz.cnf
```

\# Sign the certificate (fill in your own made-up password from step 1)

openssl x509 -req -in pgquartz.req -CA ca.cer -CAkey ca.pem -set\_serial 101 -extensions client -days 365 -outform PEM -out pgquartz.crt

# Distribution

Use the documentation for [Generate and Roll Out New Certificates](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Nieuwe+certificaten+genereren+en+uitrollin/WebHome.html)

