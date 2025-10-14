## Introduction

PgQuartz is een community tool waarin een job geconfigureerd kan worden.

PgQuartz reads and executes the job configuration.

The job can be defined in the form of a YAML file containing:

```yaml
# Content goes here
```

- steps (what actually needs to be done)
- checks (how it can be checked that everything is ok)
- connections (definitions of the connection to the PostgreSQL environment)
- etcd config (pgquartz can wait for the same job on other servers via etcd)
- general config (debug, logfile, parallel, etc)

## Benodigdheden en afhankelijkheden

PgQuartz is installed by default with the PostgreSQL SBB, but it is only used for vaccination certificates.

More information:

- [PgQuartz jobs vaccinatiebewijs](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Technisch+Applicatie+Beheer/Vaccinatiebewijs/Scripts/WebHome.html):
  - [documentation over de jobs](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Technisch+Applicatie+Beheer/Vaccinatiebewijs/Scripts/WebHome.html)
  - [gitlab repo](https://gitlab.int.corp.com/gurus-db-team/vcbe_jobs)
- Community repo: [https://github.com/MannemSolutions/pgquartz](https://github.com/MannemSolutions/pgquartz)
  - [https://github.com/MannemSolutions/rpmbuilder/tags](https://github.com/MannemSolutions/rpmbuilder/tags)
  - [https://repo.mannemsolutions.nl/yum/pgvillage/](https://repo.mannemsolutions.nl/yum/pgvillage/)
- Docs: [https://pgquartz.readthedocs.io/en/latest/](https://pgquartz.readthedocs.io/en/latest/)
- RPM's gebouwd met RPM Builder: [Built RPMs](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/RPMs+maken+voor+stolon%252C+minio%252C+wal-g+en+etcd/WebHome.html)

