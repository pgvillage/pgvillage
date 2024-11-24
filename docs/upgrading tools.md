# Introduction

Voor het PostgreSQL standaard bouwblok is enorm veel Open Source community tooling ingezet.

Deze documentatie beschrijft hoe nieuwe versies beschikbaar komen en uitgerold kunnen worden.

In principe ligt het opleveren van nieuwe RPMS bij de volgende projecten:

- RedHat (previously SHS subscriptions were used and everything is distributed via Satellite)
- PostgreSQL (currently no subscription support has been aligned)
- Ansible (partially through the RedHat subscriptions, but it's unclear if the latest version we use falls under those subscriptions)
- PgVillage (No subscriptions)
  - Packaging of community tools such as etcd, stolon, and wal-g
  - Development and packaging of tools like pgfga, pgquartz, and pgroute66

Voor alles

- Support is available if desired,
- but
  - support has not been taken for everything and
  - it does not need to be arranged by DBT for everything.

# Dependencies

- [https://repo.mannemsolutions.nl/yum/pgvillage/](https://repo.mannemsolutions.nl/yum/pgvillage/)
- [https://download.postgresql.org/pub/repos/yum/](https://download.postgresql.org/pub/repos/yum/)
- Satellite: [https://gurus-satl6-server1.int.corp.com/](https://gurus-satl6-server1.int.corp.com/)

# Werkinstructie

- Import all packages from the relevant repositories  
- Test in the POC environment with the latest releases  
- Follow the release process to get everything into T, A, and ultimately P

# Wanneer er niets anders meer helpt

if necessary, RPMs can be built manually using this work instruction: [RPM](../../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/RPMs+maken+voor+stolon%2C+minio%2C+wal-g+en+etcd/WebHome.html)

Or look at the rpmbuilder project: [https://github.com/mannemSolutions/rpmbuilder](https://github.com/mannemSolutions/rpmbuilder)

This contains:

- Python code to create spec files
- The spec files themselves
- The latest RPMs (also available at [https://repo.mannemsolutions.nl/yum/pgvillage/](https://repo.mannemsolutions.nl/yum/pgvillage/))

