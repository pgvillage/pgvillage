# PgVillage

## Introduction
During the COVID pandemic, a large dutch government agency needed to run a very secure and High Available Postgres architecture which was easy to maintain, deploy end run.
They worked together with Mannem Solutions to design and build the design that would make them succesful.
That design is the foundation of PgVillage.

PgVillage is a solution design which can be deployen in the cloud, or on premise VM's using Ansible, and (future) can run as a Kubernetes deployment.
The solution is comprised of 100% Open Source software and meets all CloudNative primitives as [defined by CNCF](https://github.com/cncf/toc/blob/main/DEFINITION.md).

## Ansible roles

### Internal roles
All internal roles are destined to become Ansible Galaxy roles...

### Ansible galaxy rollen
All Ansible Galaxy roles are included as part of this repo, but:
- if they have changes these will be upstreamed to the original Ansible Galaxy role
- once all is upstreamed they will be replaced with references to the ansible galaxy roles instead.


## Using this playbook
For a demo on Azure please refer to [pgVillage/pgv_azure](https://github.com/pgvillage/pgv_azure).
For running on VMWare:
- this deployment was originally developed against VMWare Virtual Machines, so it will definitely work
- you do need an option to supply the RPM packages (either through satellite, or use [this repo](https://repo.mannemsolutions.nl/yum/pgvillage/)).
- Currently firewalling is not included (already managed in the original setup and managed with security groups on Azure).
  - We can easilly make that part of the solution if needed.
  - Could even be (partially) automanaged through pg_hba rules
  - Please supply [an Issue](https://github.com/pgvillage/pgvillage/issues) if you want to have it
- For other VM runtimes: It will work, and we can help you succeed.
- For Kubernetes deployments: Scheduled for 2023/Q1 using Helm, scheduled for later 2023 using an operator.
