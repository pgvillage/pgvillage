# Introduction

Momenteel wordt het Standaard PostgreSQL bouwblok alleen ondersteund met PostgreSQL 12 en 14.

Er is echter geen reden om het hierbij te houden.

Deze documentatie beschrijft hoe andere releases kunnen worden toegevoegd en wat de grenzen zijn

# Dependencies

- Satellite: [https://gurus-satl6-server1.int.corp.com/users/login](https://gurus-satl6-server1.int.corp.com/users/login)
- Ansible-postgres: [https://gitlab.int.corp.com/gurus-db-team/ansible-postgres/-/tree/dev/](https://gitlab.int.corp.com/gurus-db-team/ansible-postgres/-/tree/dev/)
- Patchen: [Patching](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Patching/WebHome.html)
- Nieuw cluster: [uitrollen PostgreSQL](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Van+server+naar+draaiende+database/WebHome.html)

# Werkinstructie

Binnen Satellite zijn de volgende kanalen aangemaakt voor het PostgreSQL SBB:

```markdown
- postgresql11_8Server_x86_64
  - Contains everything for PostgreSQL 11 and
- postgresql12_8Server_x86_64
  - Contains everything for PostgreSQL 12 and the common packages (such as proj needed for PostGIS)
- postgresql13_8Server_x86_64
  - Contains everything for PostgreSQL 13 and the common packages (such as proj needed for PostGIS)
- postgresql14_8Server_x86_64
  - Contains everything for PostgreSQL 14 and the common packages (such as proj needed for PostGIS)
- pgdg-rhel8-extras
  - Contains consul, etcd, and haproxy
- pgdg-common-rhel8
  - Contains the common packages needed for all PostgreSQL releases (such as proj needed for PostGIS)
- rhel_misc
  - Also contains pgquartz, minio, and pgroute66
```

For a new version of PostgreSQL, a new product Postgresql15_8Server_x86_64 needs to be created.

- Verify that everything operates correctly according to main lines.
- There is no expectation of immediate issues arising.

For a new RHEL version, a new product **Postgresql15_9Server_x86_64** must be created.

```markdown
For a new RHEL version, a new product **Postgresql15_9Server_x86_64** must be created.
```

- Ansible must be thoroughly tested to ensure everything still functions correctly with newer RHEL releases.
- This adjustment is significant, and one must consider potential issues in Ansible code, installed RPMs, etc.

