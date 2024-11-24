# # Introduction

The building block uses certificates for encryption of network traffic (server certificates) and for authentication (client certificates).

Here, mutual TLS (mTLS) is used, which means there is a certificate chain with a root, two intermediaries (one for the client and one for the server), and the server and client certificates.

```markdown
![chain.png](../../../../../../../../attachment/xwiki/Infrastructuur/Team%3A+DBA/Algemene+Restore+Server+voor+DBA-Linux/Postgres/Bouwsteen/mTLS/WebHome/chain.png)
```

# Generate

De chain kan worden aangevraagd bij een externe authoriteit of geheel zelf worden gegenereerd.

The current process for certificate requests is, however, very cumbersome, lengthy, and dependent on the work of other teams within the organization.

Therefore, a community tool ([chainsmith](../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/Chainsmith/WebHome.html)) is used to generate the chain.

# Background information

- Generate and distribute new chain:
  - [Generate and roll out new certificates](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Nieuwe+certificaten+genereren+en+uitrollen/WebHome.html)
  - [Replace certificates with minimal impact](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/Certificaten+vervangen+met+weinig+impact/WebHome.html)
- Generate and distribute new client certificate: [new client certificate](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/nieuw+client+certificaat/WebHome.html)
- Background information about the tool: [chainsmith](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Chainsmith/WebHome.html)
- Verify certificates and what to watch for: [openssl](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/openssl/WebHome.html)
- Information about server certificates SAN, etc.: [Server certificates](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/Server+certificaten/WebHome.html)
- Information about client certificates: [Client certificates](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/Client+certificaten/WebHome.html)

