# pgv_vagrant

Running a demo environment of pgvillage on your laptop using vagrant

## Getting started

1. Get a machine (e.a. laptop) with Ubuntu
2. Setup KVM, create machines, etc. ([See here](./steps.md))
3. Make sure all [preps](./preps.md) are ready
4. Log in to ansible host and deploy `cd git/pgvillage/ && ansible-playbook -i environments/cluster1/ functional-all.yml`
5. Be amazed
